import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels

enum IOSPasskeyWalletMaterialPreflightError: Error, Equatable {
    case unavailableWalletStore
    case noWallets
    case unavailableWalletRecord
    case duplicateWalletIdentifier
    case incompletePublicIdentity
    case missingSecretMaterial
    case unavailableSecretMaterial
    case pendingKeyMigration
    case walletStoreChanged
}

/// Counts only. This is an eligibility check, not serialized backup material or recovery evidence.
struct IOSPasskeyWalletMaterialInventory: Equatable, CustomStringConvertible, CustomDebugStringConvertible {
    let walletCount: Int
    let substrateRootCount: Int
    let ethereumRootCount: Int
    let nativeTonRootCount: Int
    let chainAccountCount: Int

    var description: String { "IOSPasskeyWalletMaterialInventory(<redacted>)" }
    var debugDescription: String { description }
}

/// Reads every persisted wallet projection, including rows the ordinary wallet UI quarantines.
/// This never uploads, exports, or marks a backup complete. A future serializer must perform its
/// own atomic material capture and original-key signing/export verification immediately before use.
final class IOSPasskeyWalletMaterialPreflight {
    typealias ReadProjections = () throws -> [MetaAccountSelectionModel]

    private let readProjections: ReadProjections
    private let readPersistedCount: (() throws -> Int)?
    private let keystore: KeystoreProtocol

    convenience init(
        storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared,
        keystore: KeystoreProtocol = Keychain()
    ) {
        let repository = storageFacade.createRepository(
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper(captureDisplayPreferences: true))
        )
        self.init(readProjections: {
            let operation = repository.fetchAllOperation(with: RepositoryFetchOptions(
                includesProperties: true, includesSubentities: true
            ))
            OperationQueue().addOperations([operation], waitUntilFinished: true)
            return try operation.extractNoCancellableResultData()
        }, readPersistedCount: {
            // CoreDataRepository counts raw CDMetaAccount rows without mapping them.
            // A mapper failure therefore cannot silently remove a wallet from coverage.
            let operation = repository.fetchCountOperation()
            OperationQueue().addOperations([operation], waitUntilFinished: true)
            return try operation.extractNoCancellableResultData()
        }, keystore: keystore)
    }

    init(
        readProjections: @escaping ReadProjections,
        readPersistedCount: (() throws -> Int)? = nil,
        keystore: KeystoreProtocol
    ) {
        self.readProjections = readProjections
        self.readPersistedCount = readPersistedCount
        self.keystore = keystore
    }

    func inspect() throws -> IOSPasskeyWalletMaterialInventory {
        let before = try snapshot()
        guard !before.isEmpty else { throw IOSPasskeyWalletMaterialPreflightError.noWallets }
        guard try optionalKey(KeystoreMigrator.pendingCleanupIdentifier) == nil else {
            throw IOSPasskeyWalletMaterialPreflightError.pendingKeyMigration
        }

        var identifiers = Set<String>()
        var substrateRoots = 0
        var ethereumRoots = 0
        var nativeTonRoots = 0
        var chainAccounts = 0

        for projection in before {
            guard projection.recordState == .supported,
                  let wallet = projection.wallet,
                  wallet.metaId == projection.identifier else {
                throw IOSPasskeyWalletMaterialPreflightError.unavailableWalletRecord
            }
            guard identifiers.insert(wallet.metaId).inserted else {
                throw IOSPasskeyWalletMaterialPreflightError.duplicateWalletIdentifier
            }

            let rootMnemonic = try inspectRoot(wallet)
            if wallet.substrateAccountId != nil { substrateRoots += 1 }
            if wallet.ethereumAddress != nil { ethereumRoots += 1 }
            if wallet.legacyTonAccount != nil { nativeTonRoots += 1 }

            for account in wallet.chainAccounts {
                try inspectChainAccount(account, wallet: wallet, rootMnemonic: rootMnemonic)
                chainAccounts += 1
            }
        }

        let after = try snapshot()
        guard before.count == after.count,
              zip(before, after).allSatisfy({ lhs, rhs in
                  lhs.identifier == rhs.identifier && lhs.recordState == rhs.recordState &&
                      lhs.wallet == rhs.wallet && lhs.isSelected == rhs.isSelected && lhs.order == rhs.order &&
                      lhs.displayPreferences == rhs.displayPreferences
              }),
              try optionalKey(KeystoreMigrator.pendingCleanupIdentifier) == nil else {
            throw IOSPasskeyWalletMaterialPreflightError.walletStoreChanged
        }

        return IOSPasskeyWalletMaterialInventory(
            walletCount: before.count,
            substrateRootCount: substrateRoots,
            ethereumRootCount: ethereumRoots,
            nativeTonRootCount: nativeTonRoots,
            chainAccountCount: chainAccounts
        )
    }

    fileprivate func snapshot() throws -> [MetaAccountSelectionModel] {
        do {
            // Stable ordering makes a missing, inserted, or changed row observable on reread.
            let projections = try readProjections().sorted { $0.identifier < $1.identifier }
            if let readPersistedCount, try readPersistedCount() != projections.count {
                throw IOSPasskeyWalletMaterialPreflightError.unavailableWalletRecord
            }
            return projections
        } catch let error as IOSPasskeyWalletMaterialPreflightError {
            throw error
        } catch {
            throw IOSPasskeyWalletMaterialPreflightError.unavailableWalletStore
        }
    }

    private func inspectRoot(_ wallet: MetaAccountModel) throws -> String? {
        let hasSubstrate = wallet.substrateAccountId != nil || wallet.substratePublicKey != nil
        // The persisted iOS model supports a Substrate root or the released TON-only
        // root. A standalone EVM root has no supported Core Data representation yet.
        guard hasSubstrate || wallet.legacyTonAccount != nil,
              (wallet.substrateAccountId == nil) == (wallet.substratePublicKey == nil),
              (wallet.ethereumAddress == nil) == (wallet.ethereumPublicKey == nil) else {
            throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
        }

        if let native = wallet.legacyTonAccount {
            guard !hasSubstrate else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            let secret = try optionalKey(KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId))
            let phrase = try optionalKey(KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
            // Released export UX needs the phrase. The signing key can be recreated
            // from a phrase whose derived key is checked against the stored TON root.
            guard let phrase else {
                throw IOSPasskeyWalletMaterialPreflightError.missingSecretMaterial
            }
            do {
                if let secret { _ = try native.validatedPrivateKey(secret) }
                _ = try native.mnemonic(from: phrase)
            } catch {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
        }

        if let accountId = wallet.substrateAccountId,
           let publicKey = wallet.substratePublicKey {
            guard let cryptoType = CryptoType(rawValue: wallet.substrateCryptoType),
                  (try? publicKey.publicKeyToAccountId()) == accountId else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            _ = try requiredKey(KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId))
            try verifyOriginalKeySigning(
                wallet: wallet, accountId: accountId, publicKey: publicKey,
                cryptoType: cryptoType, ethereumBased: false, chainId: nil
            )
        }

        if let address = wallet.ethereumAddress,
           let publicKey = wallet.ethereumPublicKey {
            guard (try? publicKey.ethereumAddressFromPublicKey()) == address else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            let secret = try requiredKey(KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId))
            guard (try? SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: secret))
                .publicKey().rawData().ethereumAddressFromPublicKey()) == address else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            try verifyOriginalKeySigning(
                wallet: wallet, accountId: address, publicKey: publicKey,
                cryptoType: .ecdsa, ethereumBased: true, chainId: nil
            )
        }

        guard hasSubstrate else { return nil }
        let entropy = try optionalKey(KeystoreTagV2.entropyTagForMetaId(wallet.metaId))
        let source = try optionalKey(KeystoreTagV2.universalWalletSecretSourceTagForMetaId(wallet.metaId))
        guard !(entropy != nil && source != nil) else {
            throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
        }
        do {
            if let entropy {
                return try IRMnemonicCreator().mnemonic(fromEntropy: entropy).toString()
            }
            if let source {
                guard String(data: source, encoding: .utf8) == UniversalWalletSeedBridge.contract else {
                    throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
                }
                let seed = try requiredKey(KeystoreTagV2.substrateSeedTagForMetaId(wallet.metaId))
                return try UniversalWalletSeedBridge.mnemonic(fromWalletSeed: seed)
            }
        } catch let error as IOSPasskeyWalletMaterialPreflightError {
            throw error
        } catch {
            throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
        }
        return nil
    }

    private func inspectChainAccount(
        _ account: ChainAccountModel,
        wallet: MetaAccountModel,
        rootMnemonic: String?
    ) throws {
        let chainId = UniversalWalletChainAccountSupport.canonicalChainId(for: account.chainId)
        guard !account.accountId.isEmpty,
              !account.publicKey.isEmpty,
              CryptoType(rawValue: account.cryptoType) != nil else {
            throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
        }

        if chainId == UniversalWalletRegistry.bitcoinMainnet.chainId ||
            chainId == UniversalWalletRegistry.bitcoinTestnet.chainId {
            let network: BitcoinKeyDerivation.Network = chainId == UniversalWalletRegistry.bitcoinMainnet.chainId
                ? .mainnet : .testnet
            guard UniversalWalletChainAccountSupport.isValidBitcoinAccount(account, chainId: chainId),
                  let rootMnemonic,
                  (try? BitcoinKeyDerivation.deriveAccount(mnemonic: rootMnemonic, network: network).publicKey) ==
                  account.publicKey else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            return
        }

        if chainId == UniversalWalletRegistry.taira.chainId {
            guard UniversalWalletChainAccountSupport.isValidTairaAccount(account),
                  let rootMnemonic,
                  (try? IrohaKeyDerivation.deriveAccount(mnemonic: rootMnemonic).publicKey) == account.publicKey else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            return
        }

        let expectedAccountId = account.ethereumBased
            ? try? account.publicKey.ethereumAddressFromPublicKey()
            : try? account.publicKey.publicKeyToAccountId()
        guard expectedAccountId == account.accountId else {
            throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
        }

        let tag = account.ethereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(wallet.metaId, accountId: account.accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId, accountId: account.accountId)
        if let secret = try optionalKey(tag) {
            if account.ethereumBased {
                guard (try? SECKeyFactory().derive(fromPrivateKey: SECPrivateKey(rawData: secret))
                    .publicKey().rawData().ethereumAddressFromPublicKey()) == account.accountId else {
                    throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
                }
            }
            guard let cryptoType = CryptoType(rawValue: account.cryptoType) else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            try verifyOriginalKeySigning(
                wallet: wallet, accountId: account.accountId, publicKey: account.publicKey,
                cryptoType: cryptoType, ethereumBased: account.ethereumBased, chainId: account.chainId
            )
            return
        }

        // Only the app's named derivation contracts may substitute a root phrase for a
        // per-chain Keychain item. Unknown chains must retain their independent secret.
        guard let rootMnemonic else {
            throw IOSPasskeyWalletMaterialPreflightError.missingSecretMaterial
        }
        let derived: Data?
        switch chainId {
        case UniversalWalletRegistry.solanaMainnet.chainId,
             UniversalWalletRegistry.solanaDevnet.chainId:
            derived = try? SolanaKeyDerivation.deriveAccount(mnemonic: rootMnemonic).publicKey
        case UniversalWalletRegistry.tonMainnetRegistryEntry.chainId:
            derived = try? TonKeyDerivation.deriveAccount(mnemonic: rootMnemonic).publicKey
        case UniversalWalletRegistry.nexus.chainId:
            derived = try? IrohaKeyDerivation.deriveAccount(mnemonic: rootMnemonic).publicKey
        default:
            derived = nil
        }
        guard derived == account.publicKey else {
            throw IOSPasskeyWalletMaterialPreflightError.missingSecretMaterial
        }
    }

    private func verifyOriginalKeySigning(
        wallet: MetaAccountModel, accountId: Data, publicKey: Data,
        cryptoType: CryptoType, ethereumBased: Bool, chainId: String?
    ) throws {
        // A domain-separated local signature proves that the Keychain item can
        // still sign for the persisted identity. Nothing leaves this process.
        let message = Data("FPBK-LOCAL-KEY-PROOF-v1".utf8) + Data(wallet.metaId.utf8) + publicKey
        let account = ChainAccountResponse(
            chainId: chainId ?? "passkey-preflight", accountId: accountId, publicKey: publicKey,
            name: wallet.name, cryptoType: cryptoType, addressPrefix: 42,
            isEthereumBased: ethereumBased, isChainAccount: chainId != nil, walletId: wallet.metaId
        )
        do {
            let signature = try SigningWrapper(
                keystore: keystore, metaId: wallet.metaId, accountResponse: account
            ).sign(message)
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
            guard verified else { throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity }
        } catch let error as IOSPasskeyWalletMaterialPreflightError {
            throw error
        } catch {
            throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
        }
    }

    private func requiredKey(_ tag: String) throws -> Data {
        guard let key = try optionalKey(tag) else {
            throw IOSPasskeyWalletMaterialPreflightError.missingSecretMaterial
        }
        return key
    }

    private func optionalKey(_ tag: String) throws -> Data? {
        do {
            let key = try keystore.fetchKey(for: tag)
            guard !key.isEmpty, key.count <= 4096 else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            return key
        } catch KeystoreError.noKeyFound {
            return nil
        } catch let error as IOSPasskeyWalletMaterialPreflightError {
            throw error
        } catch {
            throw IOSPasskeyWalletMaterialPreflightError.unavailableSecretMaterial
        }
    }
}

/// An in-memory inventory of exact Keychain bytes and their source identity.
/// This is not a portable wire format and cannot be uploaded by the disabled
/// passkey flow. The restore installer must independently validate every key.
struct IOSPasskeyWalletMaterialDraft: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    struct Wallet: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        let publicIdentity: MetaAccountModel
        let isSelected: Bool
        let order: UInt32
        let displayPreferences: PersistedWalletDisplayPreferences
        let slots: [SecretSlot]

        var description: String { "IOSPasskeyWalletMaterialDraft.Wallet(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    struct SecretSlot: Equatable, CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
        enum Role: String, CaseIterable {
            case substrateSecret
            case ethereumSecret
            case tonSecret
            case entropy
            case substrateSeed
            case ethereumSeed
            case substrateDerivation
            case ethereumDerivation
            case universalWalletSource
        }

        let role: Role
        let chainId: String?
        let accountId: Data?
        let bytes: Data

        var description: String { "IOSPasskeyWalletMaterialDraft.SecretSlot(<redacted>)" }
        var debugDescription: String { description }
        var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
    }

    let wallets: [Wallet]

    var description: String { "IOSPasskeyWalletMaterialDraft(<redacted>)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: ["summary": description]) }
}

/// Captures every known V2 root/chain secret slot without invoking the old
/// single-wallet export format. The repeated reads detect ordinary Core Data
/// or Keychain drift; they are not an atomic transaction across those stores.
final class IOSPasskeyWalletMaterialDraftCapture {
    private enum KeyState: Equatable {
        case missing
        case present(Data)
    }

    private let preflight: IOSPasskeyWalletMaterialPreflight
    private let keystore: KeystoreProtocol

    convenience init(
        storageFacade: StorageFacadeProtocol = UserDataStorageFacade.shared,
        keystore: KeystoreProtocol = Keychain()
    ) {
        self.init(
            preflight: IOSPasskeyWalletMaterialPreflight(storageFacade: storageFacade, keystore: keystore),
            keystore: keystore
        )
    }

    init(preflight: IOSPasskeyWalletMaterialPreflight, keystore: KeystoreProtocol) {
        self.preflight = preflight
        self.keystore = keystore
    }

    func capture() throws -> IOSPasskeyWalletMaterialDraft {
        let before = try preflight.snapshot()
        var observed = [String: KeyState]()
        var captured = [IOSPasskeyWalletMaterialDraft.Wallet]()
        for projection in before {
            guard projection.recordState == .supported,
                  let wallet = projection.wallet,
                  let displayPreferences = projection.displayPreferences,
                  wallet.metaId == projection.identifier else {
                throw IOSPasskeyWalletMaterialPreflightError.unavailableWalletRecord
            }
            var slots = [IOSPasskeyWalletMaterialDraft.SecretSlot]()
            for role in IOSPasskeyWalletMaterialDraft.SecretSlot.Role.allCases {
                try appendSlot(
                    role, wallet: wallet, chainId: nil, accountId: nil,
                    observed: &observed, slots: &slots
                )
            }
            let chainAccounts = wallet.chainAccounts.sorted {
                if $0.chainId != $1.chainId { return $0.chainId < $1.chainId }
                if $0.accountId != $1.accountId {
                    return $0.accountId.lexicographicallyPrecedes($1.accountId)
                }
                if $0.publicKey != $1.publicKey {
                    return $0.publicKey.lexicographicallyPrecedes($1.publicKey)
                }
                return $0.cryptoType < $1.cryptoType
            }
            for account in chainAccounts {
                for role in IOSPasskeyWalletMaterialDraft.SecretSlot.Role.allCases {
                    guard role != .universalWalletSource else { continue }
                    try appendSlot(
                        role, wallet: wallet, chainId: account.chainId,
                        accountId: account.accountId, observed: &observed, slots: &slots
                    )
                }
            }
            captured.append(.init(
                publicIdentity: wallet.replacingIsBackuped(false),
                isSelected: projection.isSelected, order: projection.order,
                displayPreferences: displayPreferences, slots: slots
            ))
        }

        // Validate signing after capturing the bytes. The final reread then
        // rejects a stable substitution between the proof and this draft.
        let inventory = try preflight.inspect()
        guard before.count == inventory.walletCount else {
            throw IOSPasskeyWalletMaterialPreflightError.walletStoreChanged
        }
        let after = try preflight.snapshot()
        guard projectionsMatch(before, after),
              try keyState(KeystoreMigrator.pendingCleanupIdentifier) == .missing else {
            throw IOSPasskeyWalletMaterialPreflightError.walletStoreChanged
        }
        for (tag, expected) in observed {
            guard try keyState(tag) == expected else {
                throw IOSPasskeyWalletMaterialPreflightError.walletStoreChanged
            }
        }
        captured.sort {
            $0.order == $1.order
                ? $0.publicIdentity.metaId < $1.publicIdentity.metaId
                : $0.order < $1.order
        }
        return IOSPasskeyWalletMaterialDraft(wallets: captured)
    }

    private func projectionsMatch(
        _ lhs: [MetaAccountSelectionModel], _ rhs: [MetaAccountSelectionModel]
    ) -> Bool {
        lhs.count == rhs.count && zip(lhs, rhs).allSatisfy { first, second in
            first.identifier == second.identifier &&
                first.recordState == second.recordState &&
                first.wallet == second.wallet &&
                first.isSelected == second.isSelected &&
                first.order == second.order &&
                first.displayPreferences == second.displayPreferences
        }
    }

    private func appendSlot(
        _ role: IOSPasskeyWalletMaterialDraft.SecretSlot.Role,
        wallet: MetaAccountModel,
        chainId: String?,
        accountId: Data?,
        observed: inout [String: KeyState],
        slots: inout [IOSPasskeyWalletMaterialDraft.SecretSlot]
    ) throws {
        let tag = tagFor(role, metaId: wallet.metaId, accountId: accountId)
        let state: KeyState
        if let prior = observed[tag] {
            state = prior
        } else {
            state = try keyState(tag)
            observed[tag] = state
        }
        if case let .present(bytes) = state {
            slots.append(.init(role: role, chainId: chainId, accountId: accountId, bytes: bytes))
        }
    }

    private func tagFor(
        _ role: IOSPasskeyWalletMaterialDraft.SecretSlot.Role,
        metaId: String, accountId: Data?
    ) -> String {
        switch role {
        case .substrateSecret:
            return KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)
        case .ethereumSecret:
            return KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
        case .tonSecret:
            return KeystoreTagV2.tonSecretKeyTagForMetaId(metaId, accountId: accountId)
        case .entropy:
            return KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        case .substrateSeed:
            return KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)
        case .ethereumSeed:
            return KeystoreTagV2.ethereumSeedTagForMetaId(metaId, accountId: accountId)
        case .substrateDerivation:
            return KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId)
        case .ethereumDerivation:
            return KeystoreTagV2.ethereumDerivationTagForMetaId(metaId, accountId: accountId)
        case .universalWalletSource:
            return KeystoreTagV2.universalWalletSecretSourceTagForMetaId(metaId)
        }
    }

    private func keyState(_ tag: String) throws -> KeyState {
        do {
            let bytes = try keystore.fetchKey(for: tag)
            guard !bytes.isEmpty, bytes.count <= 4096 else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            return .present(bytes)
        } catch KeystoreError.noKeyFound {
            return .missing
        } catch let error as IOSPasskeyWalletMaterialPreflightError {
            throw error
        } catch {
            throw IOSPasskeyWalletMaterialPreflightError.unavailableSecretMaterial
        }
    }
}
