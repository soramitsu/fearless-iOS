import CommonCrypto
import Foundation
import IrohaCrypto
import LocalAuthentication
import SoraKeystore
import SSFModels

/// Public facts a wallet's secrets prove, read through a keystore. The migrator computes them over
/// the legacy items and again over the protected copies: equal results mean the copies serve every
/// read path the app has, and the wallet's stored identities verify from them.
protocol ProtectedWalletIdentityChecking {
    func fingerprint(of wallet: MetaAccountModel, keystore: KeystoreProtocol) -> [String]
    /// The entries that must say `verified` before a wallet may move: its stored root identities.
    func requiredEntries(for wallet: MetaAccountModel) -> [String]
}

struct ProtectedWalletIdentityCheck: ProtectedWalletIdentityChecking {
    static let verified = "verified"

    func requiredEntries(for wallet: MetaAccountModel) -> [String] {
        var entries: [String] = []
        if wallet.substratePublicKey != nil {
            entries.append("substrate=\(Self.verified)")
        }
        if wallet.ethereumPublicKey != nil {
            entries.append("ethereum=\(Self.verified)")
        }
        if wallet.legacyTonAccount != nil {
            entries.append("ton=\(Self.verified)")
        }
        return entries
    }

    func fingerprint(of wallet: MetaAccountModel, keystore: KeystoreProtocol) -> [String] {
        var entries: [String] = []
        let provider = KeychainUniversalWalletMnemonicProvider(keystore: keystore)

        // The root phrase and password, compared in memory only through a digest.
        switch Result(catching: { try provider.rootSecret(for: wallet) }) {
        case let .success(secret?):
            entries.append("root=\(Self.digest(secret.mnemonic + "\u{0}" + secret.passphrase))")
        case .success(nil):
            entries.append("root=none")
        case let .failure(error):
            entries.append("root=error:\(Self.describe(error))")
        }

        for slot in UniversalWalletSlot.allCases {
            guard let account = slot.storedAccount(in: wallet) else {
                continue
            }
            let outcome: String
            do {
                if let secret = try provider.secret(for: wallet, slot: slot) {
                    outcome = (try? slot.publicKey(for: secret)) == account.publicKey ? Self.verified : "mismatch"
                } else {
                    outcome = "unavailable"
                }
            } catch {
                outcome = "error:\(Self.describe(error))"
            }
            entries.append("slot.\(slot.rawValue)=\(outcome)")
        }

        if let ton = wallet.legacyTonAccount {
            let outcome: String
            do {
                _ = try ton.signingCredentials(keystore: keystore, metaId: wallet.metaId)
                outcome = Self.verified
            } catch {
                outcome = "error:\(Self.describe(error))"
            }
            entries.append("ton=\(outcome)")
        }

        if let accountId = wallet.substrateAccountId, let publicKey = wallet.substratePublicKey,
           let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType) {
            entries.append("substrate=" + signs(
                wallet: wallet, keystore: keystore, accountId: accountId, publicKey: publicKey,
                cryptoType: cryptoType, ethereumBased: false, chainId: nil
            ))
        }
        if let address = wallet.ethereumAddress, let publicKey = wallet.ethereumPublicKey {
            entries.append("ethereum=" + signs(
                wallet: wallet, keystore: keystore, accountId: address, publicKey: publicKey,
                cryptoType: .ecdsa, ethereumBased: true, chainId: nil
            ))
        }

        // Chain accounts with their own key (imported for one network).
        for account in wallet.chainAccounts.sorted(by: { ($0.chainId, $0.accountId.toHex()) < ($1.chainId, $1.accountId.toHex()) }) {
            guard UniversalWalletSlot(chainId: account.chainId) == nil,
                  let cryptoType = CryptoType(rawValue: account.cryptoType) else {
                continue
            }
            let tag = account.ethereumBased
                ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: account.accountId)
                : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: account.accountId)
            guard (try? keystore.checkKey(for: tag)) == true else {
                entries.append("chain.\(account.chainId).\(account.accountId.toHex())=root")
                continue
            }
            entries.append("chain.\(account.chainId).\(account.accountId.toHex())=" + signs(
                wallet: wallet, keystore: keystore, accountId: account.accountId, publicKey: account.publicKey,
                cryptoType: cryptoType, ethereumBased: account.ethereumBased, chainId: account.chainId
            ))
        }
        return entries
    }

    /// Signs a local, domain-separated message with the stored key and verifies it against the
    /// stored public key. Nothing leaves the process.
    private func signs(
        wallet: MetaAccountModel,
        keystore: KeystoreProtocol,
        accountId: Data,
        publicKey: Data,
        cryptoType: CryptoType,
        ethereumBased: Bool,
        chainId: String?
    ) -> String {
        let message = Data("FEARLESS-PROTECTED-KEYCHAIN-PROOF-v1".utf8) + Data(wallet.metaId.utf8) + publicKey
        let account = ChainAccountResponse(
            chainId: chainId ?? "protected-keychain", accountId: accountId, publicKey: publicKey,
            name: wallet.name, cryptoType: cryptoType, addressPrefix: 42,
            isEthereumBased: ethereumBased, isChainAccount: chainId != nil, walletId: wallet.metaId
        )
        do {
            let signature = try SigningWrapper(keystore: keystore, metaId: wallet.metaId, accountResponse: account)
                .sign(message)
            let verified: Bool
            if ethereumBased {
                verified = try SECSignatureVerifier().verify(
                    signature, forOriginalData: message.keccak256(),
                    usingPublicKey: SECPublicKey(rawData: publicKey)
                )
            } else {
                switch cryptoType {
                case .sr25519:
                    verified = try SNSignatureVerifier().verify(
                        SNSignature(rawData: signature.rawData()),
                        forOriginalData: message,
                        using: SNPublicKey(rawData: publicKey)
                    )
                case .ed25519:
                    verified = try EDSignatureVerifier().verify(
                        signature, forOriginalData: message,
                        usingPublicKey: EDPublicKey(rawData: publicKey)
                    )
                case .ecdsa:
                    verified = try SECSignatureVerifier().verify(
                        signature, forOriginalData: message.blake2b32(),
                        usingPublicKey: SECPublicKey(rawData: publicKey)
                    )
                }
            }
            return verified ? Self.verified : "mismatch"
        } catch {
            return "error:\(Self.describe(error))"
        }
    }

    private static func describe(_ error: Error) -> String {
        if let error = error as? KeystoreError {
            return "keystore.\(error)"
        }
        return String(describing: type(of: error))
    }

    private static func digest(_ value: String) -> String {
        let data = Data(value.utf8)
        var output = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &output) }
        return Data(output).toHex()
    }
}

/// Moves one wallet's secrets to items that need the device owner (design doc 3.5).
///
/// Order, with one device-owner context: journal `staging` → add each protected copy → `written`
/// → read each copy back with the context and compare bytes → verify the wallet's identities
/// from the copies → `verified` (reads move) → make the public data background work needs →
/// delete the legacy originals → `committed`. Any failure before `verified` deletes this
/// attempt's copies and leaves the legacy items untouched.
final class ProtectedWalletSecretMigrator {
    enum DeferReason: String, Error, Equatable {
        case disabled
        case passcodeNotSet
        case notBackedUp
        case unknownTags
        case noSecrets
        case identityUnavailable
        case canceled
        case authenticationFailed
        case verificationFailed
        case keychainUnavailable
        case lost
    }

    enum Outcome: Equatable {
        case committed
        case alreadyCommitted
        case deferred(DeferReason)
    }

    private let legacy: KeystoreProtocol
    private let inventory: LegacyKeychainInventory
    private let protected: ProtectedSecretBackend
    private let journal: ProtectedWalletSecretJournaling
    private let authorization: WalletSecretAuthorization
    private let authorizer: DeviceOwnerAuthorizing
    private let identityCheck: ProtectedWalletIdentityChecking
    private let descriptorStore: BitcoinAccountDescriptorStore?
    private let isEnabled: () -> Bool
    private let now: () -> Date
    private let logger: LoggerProtocol?
    /// Called after each journal write; device tests use it to stop the app at a step.
    private let afterJournalSave: (ProtectedWalletSecretRecord.State) -> Void

    init(
        legacy: KeystoreProtocol = Keychain(routed: false),
        inventory: LegacyKeychainInventory = Keychain(routed: false),
        protected: ProtectedSecretBackend = ProtectedKeychain(),
        journal: ProtectedWalletSecretJournaling,
        authorization: WalletSecretAuthorization = .shared,
        authorizer: DeviceOwnerAuthorizing = SystemDeviceOwnerAuthorizer(),
        identityCheck: ProtectedWalletIdentityChecking = ProtectedWalletIdentityCheck(),
        descriptorStore: BitcoinAccountDescriptorStore? = .shared,
        isEnabled: @escaping () -> Bool = { ProtectedKeychainPolicy.isEnabled },
        now: @escaping () -> Date = Date.init,
        logger: LoggerProtocol? = Logger.shared,
        afterJournalSave: @escaping (ProtectedWalletSecretRecord.State) -> Void = { _ in }
    ) {
        self.afterJournalSave = afterJournalSave
        self.legacy = legacy
        self.inventory = inventory
        self.protected = protected
        self.journal = journal
        self.authorization = authorization
        self.authorizer = authorizer
        self.identityCheck = identityCheck
        self.descriptorStore = descriptorStore
        self.isEnabled = isEnabled
        self.now = now
        self.logger = logger
    }

    // MARK: Recovery

    /// Finishes or undoes moves an interruption left half done, and marks committed wallets whose
    /// protected items vanished. Never shows a prompt. Returns the wallets that are `lost`.
    @discardableResult
    func recoverInterrupted() -> [MetaAccountId] {
        var lost: [MetaAccountId] = []
        for record in journal.records {
            switch record.state {
            case .staging, .written:
                // The legacy items were never touched: drop this attempt's copies.
                deleteProtectedCopies(record.tags)
                save(record, state: .deferred, reason: "interrupted")
            case .verified:
                if finishCommit(record) == .lost {
                    lost.append(record.walletId)
                }
            case .committed:
                if hasLostItems(record) {
                    save(record, state: .lost, reason: DeferReason.lost.rawValue)
                    lost.append(record.walletId)
                }
            case .lost:
                lost.append(record.walletId)
            case .deferred:
                break
            }
        }
        return lost
    }

    // MARK: Eligibility

    /// The wallet's legacy wallet-secret tags when every public precondition holds.
    func eligibleTags(for wallet: MetaAccountModel) -> Result<[String], DeferReason> {
        guard isEnabled() else {
            return .failure(.disabled)
        }
        guard authorizer.isPasscodeSet else {
            return .failure(.passcodeNotSet)
        }
        // Removing the passcode erases protected items: only a wallet whose recovery the user
        // already has may depend on them.
        guard wallet.hasBackup else {
            return .failure(.notBackedUp)
        }
        let tags: [String]
        do {
            tags = try inventory.applicationTags()
        } catch {
            return .failure(.keychainUnavailable)
        }
        guard WalletSecretTag.unknownTags(in: tags, of: wallet.metaId).isEmpty else {
            return .failure(.unknownTags)
        }
        let walletTags = tags.filter { WalletSecretTag.belongs($0, to: wallet.metaId) }.sorted()
        guard !walletTags.isEmpty else {
            return .failure(.noSecrets)
        }
        return .success(walletTags)
    }

    // MARK: Migration

    /// Moves `wallet`. Runs off the main thread; shows at most one system sheet, none when
    /// `context` was already evaluated (for example by the app's Face ID unlock).
    func migrate(_ wallet: MetaAccountModel, context providedContext: LAContext? = nil) -> Outcome {
        if let record = journal.record(for: wallet.metaId) {
            switch record.state {
            case .committed:
                return .alreadyCommitted
            case .verified:
                return outcome(of: finishCommit(record))
            case .lost:
                return .deferred(.lost)
            case .staging, .written:
                deleteProtectedCopies(record.tags)
            case .deferred:
                break
            }
        }

        let tags: [String]
        switch eligibleTags(for: wallet) {
        case let .success(found):
            tags = found
        case let .failure(reason):
            return deferMigration(of: wallet, reason, tags: [])
        }

        // The legacy bytes, and the identities they prove from the whole legacy store and from
        // this wallet's items alone: equal means no item the wallet needs is left behind.
        var originals: [String: Data] = [:]
        do {
            for tag in tags {
                originals[tag] = try legacy.fetchKey(for: tag)
            }
        } catch {
            return deferMigration(of: wallet, .keychainUnavailable, tags: [])
        }
        let expected = identityCheck.fingerprint(of: wallet, keystore: legacy)
        guard identityCheck.requiredEntries(for: wallet).allSatisfy(expected.contains),
              identityCheck.fingerprint(of: wallet, keystore: Self.memoryKeystore(originals)) == expected
        else {
            return deferMigration(of: wallet, .identityUnavailable, tags: [])
        }

        let context: LAContext
        if let providedContext {
            context = providedContext
        } else {
            // The system sheet must never block the main thread; the coordinator runs this on its queue.
            guard !Thread.isMainThread else {
                return deferMigration(of: wallet, .authenticationFailed, tags: [])
            }
            do {
                context = try authorization.context(
                    reason: ProtectedKeychainStrings.migrationReason,
                    authorizer: authorizer
                )
            } catch {
                return deferMigration(of: wallet, Self.reason(for: error), tags: [])
            }
        }

        let attempts = (journal.record(for: wallet.metaId)?.attempts ?? 0) + 1
        var record = ProtectedWalletSecretRecord(
            walletId: wallet.metaId, state: .staging, tags: tags, attempts: attempts, reason: nil, updatedAt: now()
        )
        do {
            try journal.save(record)
            afterJournalSave(record.state)
        } catch {
            return .deferred(.keychainUnavailable)
        }

        // Write.
        do {
            for tag in tags {
                if try protected.exists(for: tag) {
                    try protected.delete(for: tag)
                }
                try protected.add(originals[tag] ?? Data(), for: tag)
            }
            record.state = .written
            record.updatedAt = now()
            try journal.save(record)
            afterJournalSave(record.state)
        } catch {
            return rollback(record, Self.reason(for: error))
        }

        // Read back with the device owner and compare.
        var copies: [String: Data] = [:]
        do {
            for tag in tags {
                let copy = try protected.read(for: tag, context: context)
                guard copy == originals[tag] else {
                    return rollback(record, .verificationFailed)
                }
                copies[tag] = copy
            }
        } catch {
            return rollback(record, Self.reason(for: error))
        }
        let copiesKeystore = Self.memoryKeystore(copies)
        guard identityCheck.fingerprint(of: wallet, keystore: copiesKeystore) == expected else {
            return rollback(record, .verificationFailed)
        }

        // Commit point.
        record.state = .verified
        record.updatedAt = now()
        do {
            try journal.save(record)
            afterJournalSave(record.state)
        } catch {
            return rollback(record, .keychainUnavailable)
        }

        // Public data background work needs, made from the copies in memory: no further prompt.
        if let descriptorStore {
            BitcoinAccountDescriptorBackfill(
                secretProvider: KeychainUniversalWalletMnemonicProvider(keystore: copiesKeystore),
                store: descriptorStore,
                logger: logger
            ).backfill(wallet)
        }

        return outcome(of: finishCommit(record))
    }

    // MARK: Private

    private enum CommitResult {
        case committed
        /// Not finished yet (an original could not be deleted, or the copies vanished first);
        /// every secret is still readable.
        case pending
        case lost
    }

    private func outcome(of result: CommitResult) -> Outcome {
        switch result {
        case .committed:
            return .committed
        case .pending:
            return .deferred(.keychainUnavailable)
        case .lost:
            return .deferred(.lost)
        }
    }

    /// From `verified`: deletes each legacy original whose protected copy exists, then `committed`.
    /// A copy that vanished first (passcode removed) keeps its legacy original; a tag with neither is lost.
    private func finishCommit(_ record: ProtectedWalletSecretRecord) -> CommitResult {
        var missingCopies: [String] = []
        var unreadable: [String] = []
        for tag in record.tags {
            let hasCopy: Bool
            do {
                hasCopy = try protected.exists(for: tag)
            } catch {
                return .pending
            }
            guard hasCopy else {
                missingCopies.append(tag)
                if (try? legacy.checkKey(for: tag)) != true {
                    unreadable.append(tag)
                }
                continue
            }
        }
        if !unreadable.isEmpty {
            save(record, state: .lost, reason: DeferReason.lost.rawValue)
            return .lost
        }
        if !missingCopies.isEmpty {
            // Copies vanished before the originals went: the originals are complete. Start over.
            deleteProtectedCopies(record.tags)
            save(record, state: .deferred, reason: DeferReason.passcodeNotSet.rawValue)
            return .pending
        }
        for tag in record.tags {
            do {
                if try legacy.checkKey(for: tag) {
                    try legacy.deleteKey(for: tag)
                }
            } catch {
                logger?.warning("Protected keychain: original not deleted yet; retried at the next start")
                return .pending
            }
        }
        save(record, state: .committed, reason: nil)
        return .committed
    }

    private func hasLostItems(_ record: ProtectedWalletSecretRecord) -> Bool {
        record.tags.contains { tag in
            (try? protected.exists(for: tag)) == false && (try? legacy.checkKey(for: tag)) != true
        }
    }

    private func rollback(_ record: ProtectedWalletSecretRecord, _ reason: DeferReason) -> Outcome {
        deleteProtectedCopies(record.tags)
        save(record, state: .deferred, reason: reason.rawValue)
        logger?.info("Protected keychain: wallet move deferred (\(reason.rawValue))")
        return .deferred(reason)
    }

    private func deferMigration(of wallet: MetaAccountModel, _ reason: DeferReason, tags _: [String]) -> Outcome {
        // Only a wallet already journaled records why it waits; others stay out of the router.
        if let record = journal.record(for: wallet.metaId), !record.state.readsProtected {
            save(record, state: .deferred, reason: reason.rawValue)
        }
        return .deferred(reason)
    }

    private func deleteProtectedCopies(_ tags: [String]) {
        for tag in tags {
            if (try? protected.exists(for: tag)) == true {
                try? protected.delete(for: tag)
            }
        }
    }

    private func save(_ record: ProtectedWalletSecretRecord, state: ProtectedWalletSecretRecord.State, reason: String?) {
        var updated = record
        updated.state = state
        updated.reason = reason
        updated.updatedAt = now()
        do {
            try journal.save(updated)
            afterJournalSave(state)
        } catch {
            logger?.warning("Protected keychain: journal not saved; state is recovered at the next start")
        }
    }

    private static func reason(for error: Error) -> DeferReason {
        switch error as? ProtectedKeychainError {
        case .canceled:
            return .canceled
        case .authenticationFailed, .interactionNotAllowed:
            return .authenticationFailed
        case .passcodeNotSet, .accessControlUnavailable:
            return .passcodeNotSet
        default:
            return .keychainUnavailable
        }
    }

    private static func memoryKeystore(_ items: [String: Data]) -> KeystoreProtocol {
        let keystore = InMemoryKeychain()
        for (tag, data) in items {
            try? keystore.addKey(data, with: tag)
        }
        return keystore
    }
}
