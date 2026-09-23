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
            mapper: AnyCoreDataMapper(MetaAccountSelectionMapper())
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
                      lhs.wallet == rhs.wallet && lhs.isSelected == rhs.isSelected && lhs.order == rhs.order
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

    private func snapshot() throws -> [MetaAccountSelectionModel] {
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
            guard CryptoType(rawValue: wallet.substrateCryptoType) != nil,
                  (try? publicKey.publicKeyToAccountId()) == accountId else {
                throw IOSPasskeyWalletMaterialPreflightError.incompletePublicIdentity
            }
            // This checks coverage and public metadata only for Substrate. The
            // secret-to-public binding and original-key signing/export proof are
            // still mandatory before any generation can become backup-complete.
            _ = try requiredKey(KeystoreTagV2.substrateSecretKeyTagForMetaId(wallet.metaId))
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
