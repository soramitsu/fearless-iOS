import CommonCrypto
import Foundation
import IrohaCrypto
import LocalAuthentication
import SoraKeystore
import SSFModels
import TonSwift

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

    /// Every identity a fingerprint lists must be a positive proof: a stored account its secret
    /// does not derive, a chain account no own key signs for, or a key that fails to sign defers
    /// the wallet. Only the root digest is a value rather than a proof.
    static func provesEveryIdentity(_ fingerprint: [String]) -> Bool {
        fingerprint.allSatisfy { entry in
            entry.hasPrefix("root=") ? !entry.hasPrefix("root=error") : entry.hasSuffix("=\(verified)")
        }
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
            // The stored phrase must recreate the stored account: it is the recovery source.
            let phraseTag = KeystoreTagV2.entropyTagForMetaId(wallet.metaId)
            if (try? keystore.checkKey(for: phraseTag)) == true {
                let derived = try? TonSwift.Mnemonic.mnemonicToPrivateKey(
                    mnemonicArray: ton.mnemonic(from: keystore.fetchKey(for: phraseTag)).allWords()
                ).publicKey.data
                entries.append("tonPhrase=\(derived == ton.publicKey ? Self.verified : "mismatch")")
            }
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
                // No own key: nothing here proves this account can sign. Not a proof.
                entries.append("chain.\(account.chainId).\(account.accountId.toHex())=nokey")
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
/// Order, with one device-owner context: copy, compare and switch authority under
/// `WalletSecretWriteLock` (journal `staging` → add each protected copy → `written` → read each
/// copy back with the context and compare bytes → verify every identity from the copies →
/// `verified`); then make the public data background work needs, delete each legacy original
/// whose copy still exists, `committed`. Any failure before `verified` deletes this attempt's
/// copies of items whose originals exist and leaves the originals untouched. No step ever deletes
/// the only copy of an item.
final class ProtectedWalletSecretMigrator {
    enum DeferReason: String, Error, Equatable {
        case disabled
        case passcodeNotSet
        /// No recovery evidence covers every item of the wallet (`ProtectedKeychainRecoveryEvidence`).
        case recoveryUnverified
        case unknownTags
        case noSecrets
        case identityUnavailable
        case changedDuringMove
        case canceled
        case authenticationFailed
        case verificationFailed
        case keychainUnavailable
        /// Some copies vanished while their originals remain: both are kept.
        case copyMissing
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
    private let evidence: ProtectedKeychainRecoveryEvidence
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
        evidence: ProtectedKeychainRecoveryEvidence = .shared,
        descriptorStore: BitcoinAccountDescriptorStore? = .shared,
        isEnabled: @escaping () -> Bool = { ProtectedKeychainPolicy.isEnabled },
        now: @escaping () -> Date = Date.init,
        logger: LoggerProtocol? = Logger.shared,
        afterJournalSave: @escaping (ProtectedWalletSecretRecord.State) -> Void = { _ in }
    ) {
        self.legacy = legacy
        self.inventory = inventory
        self.protected = protected
        self.journal = journal
        self.authorization = authorization
        self.authorizer = authorizer
        self.identityCheck = identityCheck
        self.evidence = evidence
        self.descriptorStore = descriptorStore
        self.isEnabled = isEnabled
        self.now = now
        self.logger = logger
        self.afterJournalSave = afterJournalSave
    }

    // MARK: Recovery

    /// Finishes or undoes moves an interruption left half done, and marks committed wallets whose
    /// protected items vanished. Never shows a prompt and never deletes the only copy of an item.
    /// Returns the wallets that are `lost`.
    @discardableResult
    func recoverInterrupted() -> [MetaAccountId] {
        var lost: [MetaAccountId] = []
        for record in journal.records {
            switch record.state {
            case .staging, .written:
                // Authority never left the originals: drop this attempt's copies where an original exists.
                deleteCopiesBackedByOriginals(record.tags)
                save(record, state: .deferred, reason: "interrupted")
            case .verified:
                if finishCommit(record) == .lost {
                    lost.append(record.walletId)
                }
            case .committed:
                if lostTags(record).isEmpty == false {
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
        // Removing the passcode erases protected items: every item must be one the user has shown
        // they can recover.
        guard walletTags.allSatisfy({ evidence.covers(tag: $0, walletId: wallet.metaId) }) else {
            return .failure(.recoveryUnverified)
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
                deleteCopiesBackedByOriginals(record.tags)
            case .deferred:
                // Copies kept because their originals vanished first are never retried over.
                if record.reason == DeferReason.copyMissing.rawValue {
                    return .deferred(.copyMissing)
                }
            }
        }

        let tags: [String]
        switch eligibleTags(for: wallet) {
        case let .success(found):
            tags = found
        case let .failure(reason):
            return deferMigration(of: wallet, reason)
        }

        // The legacy bytes, and the identities they prove from the whole legacy store and from
        // this wallet's items alone: equal means no item the wallet needs is left behind.
        guard let originals = try? read(tags) else {
            return deferMigration(of: wallet, .keychainUnavailable)
        }
        // An item a recovery-phrase check proved must still hold the bytes it compared.
        guard evidence.stillMatches(originals, walletId: wallet.metaId) else {
            return deferMigration(of: wallet, .recoveryUnverified)
        }
        let expected = identityCheck.fingerprint(of: wallet, keystore: legacy)
        guard ProtectedWalletIdentityCheck.provesEveryIdentity(expected),
              identityCheck.requiredEntries(for: wallet).allSatisfy(expected.contains),
              identityCheck.fingerprint(of: wallet, keystore: Self.memoryKeystore(originals)) == expected
        else {
            return deferMigration(of: wallet, .identityUnavailable)
        }

        let context: LAContext
        if let providedContext {
            context = providedContext
        } else {
            // The system sheet must never block the main thread; the coordinator runs this on its queue.
            guard !Thread.isMainThread else {
                return deferMigration(of: wallet, .authenticationFailed)
            }
            do {
                context = try authorization.context(
                    reason: ProtectedKeychainStrings.migrationReason,
                    authorizer: authorizer
                )
            } catch {
                return deferMigration(of: wallet, Self.reason(for: error))
            }
        }

        // No wallet-secret write may land between the copy and the switch of authority.
        let switched: Result<ProtectedWalletSecretRecord, DeferReason> = WalletSecretWriteLock.perform {
            copyAndSwitch(wallet, tags: tags, originals: originals, expected: expected, context: context)
        }
        let record: ProtectedWalletSecretRecord
        switch switched {
        case let .success(verified):
            record = verified
        case let .failure(reason):
            return .deferred(reason)
        }

        // Public data background work needs, made from the copies already compared: no further prompt.
        if let descriptorStore {
            BitcoinAccountDescriptorBackfill(
                secretProvider: KeychainUniversalWalletMnemonicProvider(keystore: Self.memoryKeystore(originals)),
                store: descriptorStore,
                logger: logger
            ).backfill(wallet)
        }

        return outcome(of: finishCommit(record))
    }

    // MARK: Private

    private func copyAndSwitch(
        _ wallet: MetaAccountModel,
        tags: [String],
        originals: [String: Data],
        expected: [String],
        context: LAContext
    ) -> Result<ProtectedWalletSecretRecord, DeferReason> {
        // The sheet may have taken a while: an import or recovery could have changed the items.
        guard case let .success(current) = eligibleTags(for: wallet), current == tags,
              (try? read(tags)) == originals else {
            return .failure(.changedDuringMove)
        }

        let attempts = (journal.record(for: wallet.metaId)?.attempts ?? 0) + 1
        var record = ProtectedWalletSecretRecord(
            walletId: wallet.metaId, state: .staging, tags: tags, attempts: attempts, reason: nil, updatedAt: now()
        )
        do {
            try journal.save(record)
            afterJournalSave(record.state)
        } catch {
            return .failure(.keychainUnavailable)
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
            return .failure(rollback(record, Self.reason(for: error)))
        }

        // Read back with the device owner and compare.
        var copies: [String: Data] = [:]
        do {
            for tag in tags {
                let copy = try protected.read(for: tag, context: context)
                guard copy == originals[tag] else {
                    return .failure(rollback(record, .verificationFailed))
                }
                copies[tag] = copy
            }
        } catch {
            return .failure(rollback(record, Self.reason(for: error)))
        }
        guard identityCheck.fingerprint(of: wallet, keystore: Self.memoryKeystore(copies)) == expected else {
            return .failure(rollback(record, .verificationFailed))
        }

        // Commit point.
        record.state = .verified
        record.updatedAt = now()
        do {
            try journal.save(record)
            afterJournalSave(record.state)
        } catch {
            return .failure(rollback(record, .keychainUnavailable))
        }
        return .success(record)
    }

    private enum CommitResult: Equatable {
        case committed
        /// Not finished; every item is still readable from at least one store.
        case pending(DeferReason)
        case lost
    }

    private func outcome(of result: CommitResult) -> Outcome {
        switch result {
        case .committed:
            return .committed
        case let .pending(reason):
            return .deferred(reason)
        case .lost:
            return .deferred(.lost)
        }
    }

    /// From `verified`, tag by tag. An unknown answer from either store stops the step. A tag
    /// with neither copy makes the wallet `lost`; a tag whose copy vanished keeps its original and
    /// everything is kept as it is (`copyMissing`); otherwise each original is deleted right after
    /// its copy is seen to exist again, then `committed`.
    private func finishCommit(_ record: ProtectedWalletSecretRecord) -> CommitResult {
        var copyMissing = false
        var protectedOnly = false
        var anyCopy = false
        for tag in record.tags {
            guard let hasCopy = try? protected.exists(for: tag),
                  let hasOriginal = try? legacy.checkKey(for: tag) else {
                return .pending(.keychainUnavailable)
            }
            switch (hasCopy, hasOriginal) {
            case (false, false):
                save(record, state: .lost, reason: DeferReason.lost.rawValue)
                return .lost
            case (false, true):
                copyMissing = true
            case (true, false):
                protectedOnly = true
                anyCopy = true
            case (true, true):
                anyCopy = true
            }
        }
        if copyMissing, !anyCopy {
            // Every original is still there (copies vanished, typically the passcode was removed):
            // authority goes back to them and a later move may start again.
            deleteCopiesBackedByOriginals(record.tags)
            save(record, state: .deferred, reason: DeferReason.passcodeNotSet.rawValue)
            return .pending(.passcodeNotSet)
        }
        if copyMissing {
            // Some copies remain (possibly newer than their originals) and others are gone: keep
            // every copy and every original; nothing is retried over them.
            save(record, state: .deferred, reason: DeferReason.copyMissing.rawValue)
            return .pending(.copyMissing)
        }
        for tag in record.tags {
            do {
                // Checked again right before each delete.
                guard try protected.exists(for: tag) else {
                    save(record, state: .deferred, reason: DeferReason.copyMissing.rawValue)
                    return .pending(.copyMissing)
                }
                if try legacy.checkKey(for: tag) {
                    try legacy.deleteKey(for: tag)
                }
            } catch {
                logger?.warning("Protected keychain: original not deleted yet; retried at the next start")
                return .pending(.keychainUnavailable)
            }
        }
        save(record, state: .committed, reason: nil)
        return .committed
    }

    /// Tags with neither copy. An unknown answer counts as present.
    private func lostTags(_ record: ProtectedWalletSecretRecord) -> [String] {
        record.tags.filter { tag in
            (try? protected.exists(for: tag)) == false && (try? legacy.checkKey(for: tag)) == false
        }
    }

    private func rollback(_ record: ProtectedWalletSecretRecord, _ reason: DeferReason) -> DeferReason {
        deleteCopiesBackedByOriginals(record.tags)
        save(record, state: .deferred, reason: reason.rawValue)
        logger?.info("Protected keychain: wallet move deferred (\(reason.rawValue))")
        return reason
    }

    private func deferMigration(of wallet: MetaAccountModel, _ reason: DeferReason) -> Outcome {
        // Only a wallet already journaled records why it waits; others stay out of the journal.
        if let record = journal.record(for: wallet.metaId), !record.state.readsProtected {
            save(record, state: .deferred, reason: reason.rawValue)
        }
        return .deferred(reason)
    }

    /// Deletes copies only where the original still exists: a copy is never the last one deleted.
    private func deleteCopiesBackedByOriginals(_ tags: [String]) {
        for tag in tags where (try? legacy.checkKey(for: tag)) == true {
            if (try? protected.exists(for: tag)) == true {
                try? protected.delete(for: tag)
            }
        }
    }

    private func read(_ tags: [String]) throws -> [String: Data] {
        var result: [String: Data] = [:]
        for tag in tags {
            result[tag] = try legacy.fetchKey(for: tag)
        }
        return result
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
