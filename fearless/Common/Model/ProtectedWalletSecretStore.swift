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

    var version = 1
    let walletId: MetaAccountId
    var state: State
    var tags: [String]
    var attempts: Int
    var reason: String?
    var updatedAt: Date
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
        cache = try Self.loadAll(service: service)
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

    private static func loadAll(service: String) throws -> [MetaAccountId: ProtectedWalletSecretRecord] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnAttributes as String: kCFBooleanTrue as Any,
            kSecReturnData as String: kCFBooleanTrue as Any,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        var items: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &items)
        if status == errSecItemNotFound {
            return [:]
        }
        try check(status)
        var result: [MetaAccountId: ProtectedWalletSecretRecord] = [:]
        for item in (items as? [[String: Any]]) ?? [] {
            guard let data = item[kSecValueData as String] as? Data,
                  let record = try? decoder.decode(ProtectedWalletSecretRecord.self, from: data)
            else {
                continue
            }
            result[record.walletId] = record
        }
        return result
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

/// Sends the wallet-secret tags of journaled wallets to protected items (design doc 3.2).
///
/// - A wallet that is not moved, or whose move has not reached `verified`, reads its legacy items;
///   if one is missing and a protected copy exists, that copy.
/// - From `verified` on, reads go to the protected item; only a missing item (never a cancelled
///   sheet or a failed authentication) falls back to a legacy item.
/// - Writes go where reads go; deletes remove both.
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
            do {
                return try readProtected(identifier)
            } catch ProtectedKeychainError.noKeyFound {
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
        guard readsProtected(identifier) else {
            return try legacy.addKey(key, with: identifier)
        }
        do {
            try protected.add(key, for: identifier)
        } catch ProtectedKeychainError.duplicatedItem {
            throw KeystoreError.duplicatedItem
        }
    }

    func updateKey(_ key: Data, with identifier: String) throws {
        guard readsProtected(identifier) else {
            return try legacy.updateKey(key, with: identifier)
        }
        guard try protected.exists(for: identifier) else {
            return try protected.add(key, for: identifier)
        }
        let context = try authorization.context(reason: ProtectedKeychainStrings.readReason, authorizer: authorizer)
        try protected.update(key, for: identifier, context: context)
    }

    func deleteKey(for identifier: String) throws {
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

    private func walletRecord(for tag: String) -> ProtectedWalletSecretRecord? {
        journal.records.first { WalletSecretTag.belongs(tag, to: $0.walletId) }
    }

    private func readsProtected(_ tag: String) -> Bool {
        walletRecord(for: tag)?.state.readsProtected == true
    }

    private func readProtected(_ tag: String) throws -> Data {
        let context = try authorization.context(reason: ProtectedKeychainStrings.readReason, authorizer: authorizer)
        return try protected.read(for: tag, context: context)
    }
}
