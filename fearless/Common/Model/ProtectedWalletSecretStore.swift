import CryptoKit
import Foundation
import LocalAuthentication
import Security
import SoraKeystore

// MARK: - Tags

/// The wallet-secret tags (`KeystoreTagV2`): `<metaId>[accountId hex]<suffix>`. Only these move to
/// protected items; the PIN, PIN attempts, biometric enrollment, TON Connect, WalletConnect and
/// passkey items never do.
enum WalletSecretTag {
    static let suffixes = [
        "-substrateSecretKey",
        "-ethereumSecretKey",
        "-tonSecretKey",
        "-entropy",
        "-substrateDeriv",
        "-ethereumDeriv",
        "-substrateSeed",
        "-ethereumSeed",
        "-universalWalletSecretSource"
    ]

    /// True when `tag` is one of `walletId`'s wallet-secret tags.
    static func belongs(_ tag: String, to walletId: MetaAccountId) -> Bool {
        guard !walletId.isEmpty, tag.hasPrefix(walletId) else {
            return false
        }
        let rest = tag.dropFirst(walletId.count)
        guard let suffix = suffixes.first(where: { rest.hasSuffix($0) }) else {
            return false
        }
        let accountHex = rest.dropLast(suffix.count)
        // An account id is at least 20 bytes (Ethereum); a shorter run could be another wallet's id.
        return accountHex.isEmpty || (
            accountHex.count >= 40 && accountHex.count.isMultiple(of: 2) &&
                accountHex.allSatisfy { ("0" ... "9").contains($0) || ("a" ... "f").contains($0) }
        )
    }

    /// The account a tag of `walletId` belongs to: "" for the wallet's root items, the account id
    /// in hex for an account imported on its own. Nil for other tags.
    static func accountScope(of tag: String, walletId: MetaAccountId) -> String? {
        guard belongs(tag, to: walletId),
              let suffix = suffixes.first(where: { tag.hasSuffix($0) }) else {
            return nil
        }
        return String(tag.dropFirst(walletId.count).dropLast(suffix.count))
    }

    /// True when `tag` ends like a wallet-secret tag of some wallet.
    static func hasWalletSuffix(_ tag: String) -> Bool {
        suffixes.contains { tag.hasSuffix($0) && tag.count > $0.count }
    }

    /// The tags in `inventory` that start with `walletId` but are not wallet-secret tags of it.
    /// Any such tag stops a migration: it may be material this design does not know.
    static func unknownTags(in inventory: [String], of walletId: MetaAccountId) -> [String] {
        inventory.filter { $0.hasPrefix(walletId) && !belongs($0, to: walletId) }
    }
}

// MARK: - Backends

/// Items that need the device owner. `ProtectedKeychain` in the app; an in-memory double in tests.
protocol ProtectedSecretBackend: AnyObject {
    func add(_ data: Data, for account: String) throws
    func read(for account: String, context: LAContext) throws -> Data
    func update(_ data: Data, for account: String, context: LAContext) throws
    func exists(for account: String) throws -> Bool
    func delete(for account: String) throws
    func allAccounts() throws -> [String]
}

extension ProtectedKeychain: ProtectedSecretBackend {}

/// The application tags of the legacy key items, read without their data.
protocol LegacyKeychainInventory: AnyObject {
    func applicationTags() throws -> [String]
}

extension Keychain: LegacyKeychainInventory {}

// MARK: - Journal

/// Where one wallet's move to protected items stands. No secret, and no hash of one.
struct ProtectedWalletSecretRecord: Codable, Equatable {
    enum State: String, Codable {
        /// Protected copies are being written; the legacy items are complete and authoritative.
        case staging
        /// Every copy is written, not yet read back and compared.
        case written
        /// Every copy was read back with the device owner, compared and its public identities
        /// verified. The commit point: reads use the protected items from here.
        case verified
        /// The legacy originals are deleted.
        case committed
        /// Not moved; `reason` says why. The legacy items are authoritative.
        case deferred
        /// Committed, then the protected items disappeared (the passcode was removed).
        case lost

        /// Whether reads go to the protected items first.
        var readsProtected: Bool {
            switch self {
            case .verified, .committed, .lost:
                return true
            case .staging, .written, .deferred:
                return false
            }
        }
    }

    static let currentVersion = 1

    var version = ProtectedWalletSecretRecord.currentVersion
    let walletId: MetaAccountId
    var state: State
    var tags: [String]
    var attempts: Int
    var reason: String?
    var updatedAt: Date

    /// A record is trusted only when it is this version, names the item it was read from, and
    /// lists only that wallet's own wallet-secret tags.
    func isValid(storedUnder account: String) -> Bool {
        version == Self.currentVersion && walletId == account && !tags.isEmpty
            && tags.allSatisfy { WalletSecretTag.belongs($0, to: walletId) }
    }
}

protocol ProtectedWalletSecretJournaling: AnyObject {
    var records: [ProtectedWalletSecretRecord] { get }
    func record(for walletId: MetaAccountId) -> ProtectedWalletSecretRecord?
    func save(_ record: ProtectedWalletSecretRecord) throws
    func remove(walletId: MetaAccountId) throws
}

/// The journal in generic-password items readable after the first unlock, never synchronized,
/// so it stays on the device with the items it describes. Cached in memory.
final class KeychainProtectedWalletSecretJournal: ProtectedWalletSecretJournaling {
    static let service = "jp.co.soramitsu.fearless.wallet-secret-journal"

    private let service: String
    private let lock = NSLock()
    private var cache: [MetaAccountId: ProtectedWalletSecretRecord] = [:]

    init(service: String = KeychainProtectedWalletSecretJournal.service) throws {
        self.service = service
        let loaded = try Self.loadAll(service: service)
        cache = loaded.records
        invalidWalletIds = loaded.invalid
    }

    var records: [ProtectedWalletSecretRecord] {
        lock.lock()
        defer { lock.unlock() }
        return cache.values.sorted { $0.walletId < $1.walletId }
    }

    func record(for walletId: MetaAccountId) -> ProtectedWalletSecretRecord? {
        lock.lock()
        defer { lock.unlock() }
        return cache[walletId]
    }

    func save(_ record: ProtectedWalletSecretRecord) throws {
        let data = try Self.encoder.encode(record)
        lock.lock()
        defer { lock.unlock() }
        var query = baseQuery(record.walletId)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            query[kSecValueData as String] = data
            try Self.check(SecItemAdd(query as CFDictionary, nil))
        } else {
            try Self.check(status)
        }
        cache[record.walletId] = record
    }

    func remove(walletId: MetaAccountId) throws {
        lock.lock()
        defer { lock.unlock() }
        let status = SecItemDelete(baseQuery(walletId) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProtectedKeychainError.unexpected(status)
        }
        cache[walletId] = nil
    }

    private func baseQuery(_ walletId: MetaAccountId) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: walletId,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    /// Wallets whose record could not be decoded or validated. The router treats them as having
    /// no journal: each tag stays with whichever store holds it.
    private(set) var invalidWalletIds: [MetaAccountId] = []

    /// Accounts first (attributes only), then each record on its own: iOS does not return the data
    /// of every generic password in one query.
    private static func loadAll(
        service: String
    ) throws -> (records: [MetaAccountId: ProtectedWalletSecretRecord], invalid: [MetaAccountId]) {
        let listQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(listQuery as CFDictionary, &items)
        if status == errSecItemNotFound {
            return ([:], [])
        }
        try check(status)
        let accounts = ((items as? [[String: Any]]) ?? []).compactMap { $0[kSecAttrAccount as String] as? String }

        var records: [MetaAccountId: ProtectedWalletSecretRecord] = [:]
        var invalid: [MetaAccountId] = []
        for account in accounts {
            let itemQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
                kSecReturnData as String: kCFBooleanTrue as Any,
                kSecMatchLimit as String: kSecMatchLimitOne
            ]
            var data: CFTypeRef?
            try check(SecItemCopyMatching(itemQuery as CFDictionary, &data))
            guard let bytes = data as? Data,
                  let record = try? decoder.decode(ProtectedWalletSecretRecord.self, from: bytes),
                  record.isValid(storedUnder: account)
            else {
                invalid.append(account)
                continue
            }
            records[account] = record
        }
        return (records, invalid)
    }

    private static func check(_ status: OSStatus) throws {
        guard status == errSecSuccess else {
            throw ProtectedKeychain.error(for: status)
        }
    }
}

// MARK: - Router

enum ProtectedKeychainStrings {
    static var readReason: String {
        NSLocalizedString(
            "protected.keychain.read.reason",
            value: "Approve access to your wallet keys",
            comment: "System sheet reason when the app reads a protected wallet key"
        )
    }

    static var migrationReason: String {
        NSLocalizedString(
            "protected.keychain.migration.reason",
            value: "Protect your wallet keys with your iPhone passcode",
            comment: "System sheet reason when the app moves wallet keys to protected storage"
        )
    }
}

/// Serializes wallet-secret writes with the part of a move that copies, compares and switches
/// authority, so no write lands in a store the move is about to retire.
enum WalletSecretWriteLock {
    private static let lock = NSRecursiveLock()

    static func perform<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }
}

/// Routes wallet-secret tags between the legacy and the protected items (design doc 3.2).
///
/// - A tag whose wallet's move reached `verified` reads its protected item when one exists
///   (checked without a prompt), else its legacy item. A cancelled sheet or failed
///   authentication never falls back to the legacy item.
/// - Any other tag reads its legacy item, else a protected item left by an earlier move.
/// - Writes go to the protected item only for tags a verified move covered; a tag added to a
///   moved wallet later stays legacy until a move covers it. Without a usable journal, the store
///   that holds the tag keeps it. Deletes remove both.
final class ProtectedWalletSecretRouter: KeychainItemRouting, KeystoreProtocol {
    private let legacy: KeystoreProtocol
    private let protected: ProtectedSecretBackend
    private let journal: ProtectedWalletSecretJournaling
    private let authorization: WalletSecretAuthorization
    private let authorizer: DeviceOwnerAuthorizing

    init(
        legacy: KeystoreProtocol = Keychain(routed: false),
        protected: ProtectedSecretBackend = ProtectedKeychain(),
        journal: ProtectedWalletSecretJournaling,
        authorization: WalletSecretAuthorization = .shared,
        authorizer: DeviceOwnerAuthorizing = SystemDeviceOwnerAuthorizer()
    ) {
        self.legacy = legacy
        self.protected = protected
        self.journal = journal
        self.authorization = authorization
        self.authorizer = authorizer
    }

    /// Every wallet-shaped tag, journaled or not: a wallet whose journal is missing still finds
    /// its protected items when the legacy ones are gone.
    func routedKeystore(for identifier: String) -> KeystoreProtocol? {
        WalletSecretTag.hasWalletSuffix(identifier) ? self : nil
    }

    func fetchKey(for identifier: String) throws -> Data {
        if readsProtected(identifier) {
            // Existence first, without a prompt: a vanished item (passcode removed) must reach a
            // surviving legacy original instead of failing at the sheet.
            guard try protected.exists(for: identifier) else {
                return try legacy.fetchKey(for: identifier)
            }
            do {
                return try readProtected(identifier)
            } catch ProtectedKeychainError.noKeyFound {
                // Gone between the check and the read (the passcode was just removed).
                return try legacy.fetchKey(for: identifier)
            }
        }
        do {
            return try legacy.fetchKey(for: identifier)
        } catch KeystoreError.noKeyFound {
            guard try protected.exists(for: identifier) else {
                throw KeystoreError.noKeyFound
            }
            return try readProtected(identifier)
        }
    }

    func checkKey(for identifier: String) throws -> Bool {
        try legacy.checkKey(for: identifier) || protected.exists(for: identifier)
    }

    func addKey(_ key: Data, with identifier: String) throws {
        try WalletSecretWriteLock.perform {
            guard try writesProtected(identifier) else {
                return try legacy.addKey(key, with: identifier)
            }
            do {
                try protected.add(key, for: identifier)
            } catch ProtectedKeychainError.duplicatedItem {
                throw KeystoreError.duplicatedItem
            }
        }
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        try WalletSecretWriteLock.perform {
            guard try writesProtected(identifier) else {
                return try legacy.updateKey(key, with: identifier)
            }
            guard try protected.exists(for: identifier) else {
                return try protected.add(key, for: identifier)
            }
            let context = try authorization.context(reason: ProtectedKeychainStrings.readReason, authorizer: authorizer)
            try protected.update(key, for: identifier, context: context)
        }
    }

    func deleteKey(for identifier: String) throws {
        try WalletSecretWriteLock.perform {
            var deleted = false
            if try legacy.checkKey(for: identifier) {
                try legacy.deleteKey(for: identifier)
                deleted = true
            }
            if try protected.exists(for: identifier) {
                try protected.delete(for: identifier)
                deleted = true
            }
            guard deleted else {
                throw KeystoreError.noKeyFound
            }
        }
    }

    private func walletRecord(for tag: String) -> ProtectedWalletSecretRecord? {
        journal.records.first { WalletSecretTag.belongs(tag, to: $0.walletId) }
    }

    private func readsProtected(_ tag: String) -> Bool {
        walletRecord(for: tag)?.state.readsProtected == true
    }

    private func writesProtected(_ tag: String) throws -> Bool {
        if let record = walletRecord(for: tag), record.state.readsProtected, record.tags.contains(tag) {
            return true
        }
        // Otherwise the store that already holds the item keeps it (a missing or damaged journal,
        // or a move that stopped with some items protected only).
        return try !legacy.checkKey(for: tag) && protected.exists(for: tag)
    }

    private func readProtected(_ tag: String) throws -> Data {
        if WalletSecretAuthorization.isPromptSuppressed {
            // Background maintenance never shows a sheet: it uses an approved context it already
            // holds, captured once, or does not read at all.
            guard let context = authorization.currentContext() else {
                throw ProtectedKeychainError.interactionNotAllowed
            }
            return try protected.read(for: tag, context: context)
        }
        let context = try authorization.context(reason: ProtectedKeychainStrings.readReason, authorizer: authorizer)
        return try protected.read(for: tag, context: context)
    }
}

// MARK: - Recovery evidence

/// The items a wallet's user has shown they can recover: exactly the items one import, restore from
/// a backup, or creation with the phrase confirmed word by word wrote, recorded right then. Nothing
/// else adds to it ("skip", "I will risk it", partial cloud backups, accounts added later, recovery
/// into an existing wallet). A move takes only wallets whose every item is listed, because removing
/// the device passcode erases protected items.
final class ProtectedKeychainRecoveryEvidence {
    static let shared = ProtectedKeychainRecoveryEvidence()
    /// v3: review builds before the first shipping build wrote v2 evidence, some of it from a
    /// recovery check that proved only public keys; none of it counts.
    static let storageKey = "protectedKeychain.recoveryEvidence.v3"
    /// SHA-256 of items whose evidence is a recovery-phrase check: covered only while the item
    /// still holds those bytes.
    static let digestsKey = "protectedKeychain.recoveryEvidence.v3.digests"

    private let userDefaults: UserDefaults
    private let lock = NSLock()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Records the wallet's root items present in `keystore` (the store the import just wrote).
    func recordWrittenRootItems(walletId: MetaAccountId, keystore: KeystoreProtocol) {
        let written = WalletSecretTag.suffixes.map { walletId + $0 }.filter { (try? keystore.checkKey(for: $0)) == true }
        record(walletId: walletId, tags: written)
    }

    /// Items this build wrote from the phrase the user just entered or confirmed.
    func record(walletId: MetaAccountId, tags: [String]) {
        record(walletId: walletId, tags: tags, digests: [:])
    }

    /// Items a recovery-phrase check proved, bound to the exact bytes it compared.
    func record(walletId: MetaAccountId, items: [String: Data]) {
        record(walletId: walletId, tags: Array(items.keys), digests: items.mapValues(Self.digest))
    }

    private func record(walletId: MetaAccountId, tags: [String], digests: [String: String]) {
        let owned = tags.filter { WalletSecretTag.belongs($0, to: walletId) }
        guard !owned.isEmpty else {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        var stored = (userDefaults.dictionary(forKey: Self.storageKey) as? [String: [String]]) ?? [:]
        stored[walletId] = Array(Set(stored[walletId] ?? []).union(owned)).sorted()
        var allDigests = (userDefaults.dictionary(forKey: Self.digestsKey) as? [String: [String: String]]) ?? [:]
        var walletDigests = allDigests[walletId] ?? [:]
        for tag in owned {
            // A write this build made replaces an earlier check's binding.
            walletDigests[tag] = digests[tag]
        }
        allDigests[walletId] = walletDigests.isEmpty ? nil : walletDigests
        userDefaults.set(allDigests, forKey: Self.digestsKey)
        userDefaults.set(stored, forKey: Self.storageKey)
    }

    func covers(tag: String, walletId: MetaAccountId) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let stored = (userDefaults.dictionary(forKey: Self.storageKey) as? [String: [String]]) ?? [:]
        return stored[walletId]?.contains(tag) == true
    }

    /// True when every item in `items` that a check bound to bytes still holds those bytes.
    func stillMatches(_ items: [String: Data], walletId: MetaAccountId) -> Bool {
        lock.lock()
        let digests = ((userDefaults.dictionary(forKey: Self.digestsKey) as? [String: [String: String]]) ?? [:])[walletId]
        lock.unlock()
        guard let digests else {
            return true
        }
        return items.allSatisfy { tag, data in digests[tag].map { $0 == Self.digest(data) } ?? true }
    }

    func forget(walletId: MetaAccountId) {
        lock.lock()
        defer { lock.unlock() }
        var stored = (userDefaults.dictionary(forKey: Self.storageKey) as? [String: [String]]) ?? [:]
        stored[walletId] = nil
        userDefaults.set(stored, forKey: Self.storageKey)
        var digests = (userDefaults.dictionary(forKey: Self.digestsKey) as? [String: [String: String]]) ?? [:]
        digests[walletId] = nil
        userDefaults.set(digests, forKey: Self.digestsKey)
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
