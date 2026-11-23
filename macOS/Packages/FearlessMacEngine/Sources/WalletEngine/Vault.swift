import CryptoKit
import Foundation
import IrohaCrypto
import LocalAuthentication
import WalletCore

struct VaultDocument: Codable {
    var version = 2
    var salt: Data
    static let currentCost = 1 << 17
    var cost = Self.currentCost
    var blockSize = 8
    var parallelism = 1
    var wrappedKey: Data
    var secrets: Data
    var metadataTag: Data?
    var biometricRekeyPending: Bool?
    var failures = 0
    var retryAfter: Date?
    var biometrics = false

    enum CodingKeys: String, CodingKey {
        case version, salt, wrappedKey, secrets, failures, retryAfter, biometrics, metadataTag, biometricRekeyPending
        case cost = "n"
        case blockSize = "r"
        case parallelism = "p"
    }
}

struct WalletTransaction: Codable {
    let vault: VaultDocument
    let metadata: Data?
    let wallets: [Wallet]? // v1 journal
}

actor EngineStore: VaultServicing {
    let files: EngineFiles
    private let session: URLSession
    private let clock: @Sendable () -> Date
    private(set) var verifiedWallets: [Wallet]?
    let biometricKey: any BiometricKeyAccessing
    let mnemonicGenerator: (IRMnemonicStrength) throws -> [String]
    private var missingEntitlement = false
    private var transfersInProgress: [String: UUID] = [:]

    func beginTransfer(_ account: String) throws -> UUID {
        guard transfersInProgress[account] == nil else {
            throw WalletError.transferRejected("Another transfer from this wallet is awaiting node acceptance on this network.")
        }
        let owner = UUID()
        transfersInProgress[account] = owner
        return owner
    }

    func endTransfer(_ account: String, owner: UUID) {
        if transfersInProgress[account] == owner {
            transfersInProgress.removeValue(forKey: account)
        }
    }

    var key: SymmetricKey?
    private(set) var generation: UInt64 = 0
    private var prompts: [UUID: LAContext] = [:]
    private var observers: [UUID: AsyncStream<VaultState>.Continuation] = [:]

    init(
        configuration: WalletEngineConfiguration,
        biometrics: (any BiometricKeyAccessing)? = nil,
        clock: @escaping @Sendable () -> Date = { Date() },
        mnemonicGenerator: @escaping (IRMnemonicStrength) throws
            -> [String] = { try IRMnemonicCreator().randomMnemonic($0).allWords() }
    ) {
        session = configuration.urlSession
        self.clock = clock
        files = EngineFiles(directory: configuration.directoryURL)
        biometricKey = biometrics ?? BiometricKey(
            service: configuration.keychainService,
            account: configuration.directoryURL.path
        )
        self.mnemonicGenerator = mnemonicGenerator
    }

    func recover() throws {
        if let transaction = try files.read(WalletTransaction.self, "wallet-update.json") {
            let metadata: Data
            if transaction.vault.version == 2, let bytes = transaction.metadata {
                metadata = bytes
            } else if transaction.vault.version == 1, let records = transaction.wallets {
                metadata = try JSONEncoder().encode(records)
            } else {
                throw WalletError.storage("Unrecognized wallet journal.")
            }
            try files.write(transaction.vault, "vault.json")
            try files.write(metadata, to: "wallets.json")
            try files.remove("wallet-update.json")
        }
    }

    func document() throws -> VaultDocument {
        try recover()
        guard let doc = try files.read(VaultDocument.self, "vault.json") else { throw WalletError.vaultNotInitialized }
        guard [1, 2].contains(doc.version), [1 << 15, 1 << 16, VaultDocument.currentCost].contains(doc.cost), doc.blockSize == 8, doc.parallelism == 1,
              doc.salt.count == 32 else {
            throw WalletError.storage("Unrecognized or damaged vault.")
        }
        return doc
    }

    func state() -> VaultState {
        if key != nil {
            return .unlocked
        }
        do { _ = try document(); return .locked }
        catch WalletError.vaultNotInitialized { return .uninitialized }
        catch { return .locked }
    }

    nonisolated func stateUpdates() -> AsyncStream<VaultState> {
        AsyncStream { continuation in
            let id = UUID()
            let registration = Task { await self.subscribe(id, continuation) }
            continuation.onTermination = { _ in Task { await registration.value; await self.unsubscribe(id) } }
        }
    }

    private func subscribe(_ id: UUID, _ continuation: AsyncStream<VaultState>.Continuation) {
        observers[id] = continuation
        continuation.yield(state())
    }

    private func unsubscribe(_ id: UUID) {
        observers.removeValue(forKey: id)
    }

    private func publish(_ state: VaultState) {
        for observer in observers.values {
            observer.yield(state)
        }
    }

    private func passwordKey(_ bytes: Data, _ doc: VaultDocument) throws -> SymmetricKey {
        let data = try IRScryptKeyDeriviation().deriveKey(
            from: bytes,
            salt: doc.salt,
            scryptN: UInt(doc.cost),
            scryptP: UInt(doc.parallelism),
            scryptR: UInt(doc.blockSize),
            length: 32
        )
        return SymmetricKey(data: data)
    }

    func seal(_ plaintext: Data, key: SymmetricKey, domain: String) throws -> Data {
        guard let data = try AES.GCM.seal(plaintext, using: key, authenticating: Data(domain.utf8)).combined else {
            throw WalletError.storage("Cannot encrypt vault.")
        }
        return data
    }

    private func open(_ data: Data, key: SymmetricKey, domain: String) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key, authenticating: Data(domain.utf8))
    }

    func secrets(_ doc: VaultDocument, using key: SymmetricKey) throws -> [String: WalletSecret] {
        do {
            let clear = try open(doc.secrets, key: key, domain: "Fearless.wallets.v\(doc.version)")
            return try JSONDecoder().decode([String: WalletSecret].self, from: clear)
        } catch { throw WalletError.storage("The encrypted wallet data failed authentication.") }
    }

    /// The encrypted secrets also bind the format version through their AES-GCM domain.
    /// Deleting the MAC and declaring an old format cannot trigger a successful migration.
    private func metadataBytes(_ metadata: Data, doc: VaultDocument) -> Data {
        var bytes = Data("Fearless.wallet-metadata.v2".utf8)
        bytes.append(doc.biometrics ? 1 : 0)
        bytes.append(doc.biometricRekeyPending == true ? 1 : 0)
        bytes.append(metadata)
        return bytes
    }

    func commit(_ records: [Wallet], document: VaultDocument, using dataKey: SymmetricKey) throws {
        var doc = document
        let metadata = try JSONEncoder().encode(records)
        doc.metadataTag = Data(HMAC<SHA256>.authenticationCode(
            for: metadataBytes(metadata, doc: doc), using: dataKey
        ))
        do {
            try files.write(WalletTransaction(vault: doc, metadata: metadata, wallets: nil), "wallet-update.json")
            try recover()
        } catch {
            // A durable journal may already contain the new state. Re-authenticate on replay.
            verifiedWallets = nil
            lock()
            throw error
        }
        if key != nil {
            verifiedWallets = records
        }
    }

    private func validatedContents(_ doc: VaultDocument, key: SymmetricKey) throws -> ([Wallet], [String: WalletSecret]) {
        let entries = try secrets(doc, using: key)
        let invalid = WalletError.storage("Wallet account metadata failed verification.")
        if doc.version == 2 {
            guard let bytes = try files.contents(of: "wallets.json"),
                  let tag = doc.metadataTag, HMAC<SHA256>.isValidAuthenticationCode(
                      tag, authenticating: metadataBytes(bytes, doc: doc), using: key
                  ) else { throw invalid }
            do { return try (JSONDecoder().decode([Wallet].self, from: bytes), entries) }
            catch { throw invalid }
        }
        var records = try files.read([Wallet].self, "wallets.json") ?? []
        // The v1 format authenticated the keys, but never the watch-only records or names.
        let signingIDs = records.filter { !$0.isWatchOnly }.map { $0.id.description }
        guard signingIDs.count == entries.count, Set(signingIDs) == Set(entries.keys),
              Set(records.map(\.id)).count == records.count else { throw invalid }
        for i in records.indices where !records[i].isWatchOnly {
            guard let entry = entries[records[i].id.description] else { throw invalid }
            let accounts = try entry.accounts()
            let legacy = accounts.map { account -> WalletAccount in
                var old = account
                old.derivationPath = nil
                return old
            }
            guard legacy == records[i].accounts else { throw invalid }
            records[i].accounts = accounts
        }
        return (records, entries)
    }

    private func wrap(_ key: SymmetricKey, password: String, doc: inout VaultDocument) throws {
        doc.cost = VaultDocument.currentCost
        doc.salt = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let normalized = Data(password.precomposedStringWithCanonicalMapping.utf8)
        doc.wrappedKey = try seal(
            key.withUnsafeBytes { Data($0) }, key: passwordKey(normalized, doc), domain: "Fearless.key.v1"
        )
    }

    func initialize(password: String) throws {
        guard PasswordPolicy.isAcceptable(password) else { throw WalletError.passwordTooWeak }
        guard state() == .uninitialized else { throw WalletError.storage("The vault already exists.") }
        let records = try wallets()
        let newKey = SymmetricKey(size: .bits256)
        var doc = VaultDocument(salt: Data(), wrappedKey: Data(), secrets: Data())
        try wrap(newKey, password: password, doc: &doc)
        doc.secrets = try seal(Data("{}".utf8), key: newKey, domain: "Fearless.wallets.v2")
        try commit(records, document: doc, using: newKey)
        key = newKey
        verifiedWallets = records
        publish(.unlocked)
    }

    private func authenticatePassword(_ password: String) throws -> SymmetricKey {
        var doc = try document()
        let now = clock(), latest = now.addingTimeInterval(4096)
        if let date = doc.retryAfter, date > now {
            if date > latest {
                doc.retryAfter = latest
                try files.write(doc, "vault.json")
            }
            throw WalletError.storage("Too many attempts. Try again in \(Int(ceil(min(date, latest).timeIntervalSince(now)))) seconds.")
        }
        let normalized = Data(password.precomposedStringWithCanonicalMapping.utf8)
        var candidates = [normalized]
        let raw = Data(password.utf8)
        if doc.cost < VaultDocument.currentCost, raw != normalized {
            candidates.append(raw)
        }
        for bytes in candidates {
            let kek = try passwordKey(bytes, doc)
            if let data = try? open(doc.wrappedKey, key: kek, domain: "Fearless.key.v1"), data.count == 32 {
                let verified = SymmetricKey(data: data)
                if let key, key != verified {
                    throw WalletError.storage("The vault changed. Lock Fearless and unlock it again.")
                }
                if doc.failures != 0 || doc.retryAfter != nil {
                    doc.failures = 0
                    doc.retryAfter = nil
                    try files.write(doc, "vault.json")
                }
                return verified
            }
        }
        doc.failures = min(19, max(0, doc.failures)) + 1
        if doc.failures >= 5 {
            doc.retryAfter = clock().addingTimeInterval(Double(1 << min(12, doc.failures - 5)))
        }
        try files.write(doc, "vault.json")
        throw WalletError.wrongPassword
    }

    private func authenticate(_ approval: UserApproval) async throws -> SymmetricKey {
        switch approval {
        case let .password(password): return try authenticatePassword(password)
        case let .biometrics(reason):
            let epoch = generation
            guard try document().biometrics else { throw WalletError.biometricsUnavailable }
            let id = UUID(), context = LAContext(), item = biometricKey
            prompts[id] = context
            defer { prompts.removeValue(forKey: id); context.invalidate() }
            let verified = try await withTaskCancellationHandler {
                try await Task.detached { try item.read(reason: reason, context: context) }.value
            } onCancel: { context.invalidate() }
            guard generation == epoch, !Task.isCancelled else { throw WalletError.biometricsCancelled }
            let doc = try document()
            guard doc.biometrics else { throw WalletError.biometricsUnavailable }
            if let key, key != verified {
                throw WalletError.biometricsUnavailable
            }
            _ = try secrets(doc, using: verified)
            return verified
        }
    }

    func verify(_ approval: UserApproval) async throws {
        let verified = try await authenticate(approval)
        if key == nil {
            _ = try secrets(document(), using: verified)
        }
    }

    func unlock(_ approval: UserApproval) async throws {
        let epoch = generation
        let verified = try await authenticate(approval)
        guard epoch == generation else { throw WalletError.vaultLocked }
        let wasLocked = key == nil
        var doc = try document()
        let (records, entries) = try validatedContents(doc, key: verified)
        let migrating = doc.version == 1
        if migrating {
            doc.version = 2
            doc.biometricRekeyPending = nil
            doc.secrets = try seal(JSONEncoder().encode(entries), key: verified, domain: "Fearless.wallets.v2")
        }
        if case let .password(password) = approval, doc.cost < VaultDocument.currentCost {
            try wrap(verified, password: password, doc: &doc)
            try commit(records, document: doc, using: verified)
        } else if migrating {
            // A biometric unlock cannot rewrap the password key. Upgrade its cost at the next password unlock.
            try commit(records, document: doc, using: verified)
        }
        if case .password = approval, doc.biometricRekeyPending == true {
            // The new password always remains usable if macOS refuses to update the protected item.
            do { try finishBiometricRotation(records, doc: doc, key: verified) }
            catch WalletError.biometricsUnavailable {}
        }
        key = verified
        verifiedWallets = records
        if wasLocked {
            publish(.unlocked)
            Task { await NetworkServices(store: self, session: session).reconcileAfterUnlock() }
        }
    }

    func lock() {
        generation &+= 1
        for context in prompts.values {
            context.invalidate()
        }
        guard key != nil else { return }
        key = nil
        publish(.locked)
    }

    func changePassword(current: String, new: String) throws {
        guard PasswordPolicy.isAcceptable(new) else { throw WalletError.passwordTooWeak }
        let verified = try authenticatePassword(current)
        var doc = try document()
        let (records, entries) = try validatedContents(doc, key: verified)
        let newKey = SymmetricKey(size: .bits256)
        try wrap(newKey, password: new, doc: &doc)
        let rotateBiometrics = doc.biometrics || (doc.version == 2 && doc.biometricRekeyPending == true)
        doc.version = 2
        doc.secrets = try seal(JSONEncoder().encode(entries), key: newKey, domain: "Fearless.wallets.v2")
        doc.biometrics = false
        doc.biometricRekeyPending = rotateBiometrics
        try commit(records, document: doc, using: newKey)
        generation &+= 1
        for context in prompts.values {
            context.invalidate()
        }
        if key != nil {
            key = newKey
        }
        if rotateBiometrics {
            do { try finishBiometricRotation(records, doc: doc, key: newKey) }
            catch {
                throw WalletError.storage("Password changed. Unlock with the new password to finish updating Touch ID.")
            }
        }
    }

    private func finishBiometricRotation(_ records: [Wallet], doc: VaultDocument, key: SymmetricKey) throws {
        // This intent is authenticated in the journal. A crash on either side of the keychain
        // write retries with the password-wrapped new key, never a plaintext key on disk.
        do {
            try biometricKey.remove(allowMissingEntitlement: false)
            try biometricKey.save(key)
        } catch { throw WalletError.biometricsUnavailable }
        var completed = doc
        completed.biometrics = true
        completed.biometricRekeyPending = nil
        try commit(records, document: completed, using: key)
    }

    func biometricsAvailability() -> BiometricsAvailability {
        if missingEntitlement {
            return .unavailable(reason: "This build lacks the protected keychain entitlement.")
        }
        let status = biometricKey.availability()
        if status == .enabled, (try? document().biometrics) != true {
            return .available
        }
        return status
    }

    func setBiometricsEnabled(_ enabled: Bool, password: String) throws {
        let verified = try authenticatePassword(password)
        var doc = try document()
        let (records, entries) = try validatedContents(doc, key: verified)
        if doc.version == 1 {
            doc.version = 2
            doc.secrets = try seal(JSONEncoder().encode(entries), key: verified, domain: "Fearless.wallets.v2")
        }
        if enabled {
            if biometricsAvailability() == .enabled {
                return
            }
            guard biometricsAvailability() == .available else { throw WalletError.biometricsUnavailable }
            do {
                try biometricKey.remove(allowMissingEntitlement: true)
                try biometricKey.save(verified)
            } catch BiometricItemError.missingEntitlement {
                missingEntitlement = true
                throw WalletError.biometricsUnavailable
            }
        } else {
            try biometricKey.remove(allowMissingEntitlement: !doc.biometrics)
        }
        doc.biometrics = enabled
        doc.biometricRekeyPending = nil
        try commit(records, document: doc, using: verified)
    }

    func eraseAllData() throws {
        try files.access()
        lock()
        verifiedWallets = nil
        let old = try? document()
        let allowMissing = old?.biometrics != true && old?.biometricRekeyPending != true
        for name in ["wallet-update.json", "wallets.json", "nodes.json", "activity.json", "vault.json"] {
            try files.remove(name)
        }
        try files.removeInterruptedWrites()
        publish(.uninitialized)
        do { try biometricKey.remove(allowMissingEntitlement: allowMissing) }
        catch { throw WalletError.storage("Wallet files erased. The protected Touch ID item could not be removed.") }
    }
}
