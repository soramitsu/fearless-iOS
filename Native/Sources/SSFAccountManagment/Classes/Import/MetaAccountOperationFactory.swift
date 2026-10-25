import Foundation
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFCrypto
import SSFModels
import SSFUtils

enum AccountOperationFactoryError: Error {
    case invalidKeystore
    case keypairFactoryFailure
    case unsupportedNetwork
    case decryption
    case missingUsername
}

// sourcery: AutoMockable
public protocol MetaAccountOperationFactoryProtocol {
    func newMetaAccountOperation(
        mnemonicRequest: MetaAccountImportMnemonicRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(seedRequest: MetaAccountImportSeedRequest, isBackuped: Bool)
        -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(
        keystoreRequest: MetaAccountImportKeystoreRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel>

    func importChainAccountOperation(mnemonicRequest: ChainAccountImportMnemonicRequest)
        -> BaseOperation<MetaAccountModel>
    func importChainAccountOperation(seedRequest: ChainAccountImportSeedRequest)
        -> BaseOperation<MetaAccountModel>
    func importChainAccountOperation(keystoreRequest: ChainAccountImportKeystoreRequest)
        -> BaseOperation<MetaAccountModel>
}

public final class MetaAccountOperationFactory {
    private struct AccountQuery {
        let publicKey: Data
        let privateKey: Data
        let address: Data
        let seed: Data
    }

    private enum SeedSource {
        case mnemonic(IRMnemonicProtocol)
        case seed(Data)
    }

    private let keystore: KeystoreProtocol

    public init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }
}

private extension MetaAccountOperationFactory {
    // MARK: - Factory functions

    func createKeypairFactory(
        _ cryptoType: CryptoType,
        isEthereumBased: Bool
    ) -> KeypairFactoryProtocol {
        if isEthereumBased {
            return BIP32KeypairFactory()
        } else {
            switch cryptoType {
            case .sr25519:
                return SR25519KeypairFactory()
            case .ed25519:
                return Ed25519KeypairFactory()
            case .ecdsa:
                return EcdsaKeypairFactory()
            }
        }
    }

    // MARK: - Derivation functions

    func getJunctionResult(
        from derivationPath: String,
        ethereumBased: Bool
    ) throws -> JunctionResult? {
        guard !derivationPath.isEmpty else { return nil }

        let junctionFactory = ethereumBased ?
            BIP32JunctionFactory() : SubstrateJunctionFactory()

        return try junctionFactory.parse(path: derivationPath)
    }

    func deriveSeed(
        from mnemonic: String,
        password: String,
        ethereumBased: Bool
    ) throws -> SeedFactoryResult {
        let seedFactory: SeedFactoryProtocol = ethereumBased ?
            BIP32SeedFactory() : SeedFactory()

        return try seedFactory.deriveSeed(from: mnemonic, password: password)
    }

    // MARK: - Save functions

    func saveSecretKey(
        _ secretKey: Data,
        metaId: String,
        accountId: AccountId? = nil,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        try keystore.saveKey(secretKey, with: tag)
    }

    func saveEntropy(
        _ entropy: Data,
        metaId: String,
        accountId: AccountId? = nil
    ) throws {
        let tag = KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        try keystore.saveKey(entropy, with: tag)
    }

    func saveDerivationPath(
        _ derivationPath: String,
        metaId: String,
        accountId: AccountId? = nil,
        ethereumBased: Bool
    ) throws {
        guard !derivationPath.isEmpty,
              let derivationPathData = derivationPath.asSecretData() else { return }

        let tag = ethereumBased ?
            KeystoreTagV2.ethereumDerivationTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateDerivationTagForMetaId(metaId, accountId: accountId)

        try keystore.saveKey(derivationPathData, with: tag)
    }

    func saveSeed(
        _ seed: Data,
        metaId: String,
        accountId: AccountId? = nil,
        ethereumBased: Bool
    ) throws {
        let tag = ethereumBased ?
            KeystoreTagV2.ethereumSeedTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateSeedTagForMetaId(metaId, accountId: accountId)

        try keystore.saveKey(seed, with: tag)
    }

    // MARK: - Meta account generation function

    private func generateKeypair(
        from seed: Data,
        chaincodes: [Chaincode],
        cryptoType: CryptoType,
        isEthereum: Bool,
        seedSource: SeedSource? = nil
    ) throws -> (publicKey: Data, secretKey: Data) {
        let keypairFactory = createKeypairFactory(cryptoType, isEthereumBased: isEthereum)

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: chaincodes
        )

        if isEthereum, let seedSource = seedSource, case SeedSource.seed = seedSource {
            let privateKey = try SECPrivateKey(rawData: seed)

            return try (
                publicKey: SECKeyFactory().derive(fromPrivateKey: privateKey).publicKey().rawData(),
                secretKey: seed
            )

        } else if cryptoType == .sr25519 || isEthereum {
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: keypair.privateKey().rawData()
            )
        } else {
            guard let factory = keypairFactory as? DerivableSeedFactoryProtocol else {
                throw AccountOperationFactoryError.keypairFactoryFailure
            }

            let secretKey = try factory.deriveChildSeedFromParent(seed, chaincodeList: chaincodes)
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: secretKey
            )
        }
    }

    private func getQuery(
        seedSource: SeedSource,
        derivationPath: String,
        cryptoType: CryptoType,
        ethereumBased: Bool
    ) throws -> AccountQuery {
        let junctionResult = try getJunctionResult(
            from: derivationPath,
            ethereumBased: ethereumBased
        )

        let password = junctionResult?.password ?? ""
        let chaincodes = junctionResult?.chaincodes ?? []

        var seed: Data
        switch seedSource {
        case let .mnemonic(mnemonic):
            let seedResult = try deriveSeed(
                from: mnemonic.toString(),
                password: password,
                ethereumBased: ethereumBased
            )

            seed = ethereumBased ? seedResult.seed : seedResult.seed.miniSeed
        case let .seed(data):
            seed = data
        }

        let keypair = try generateKeypair(
            from: seed,
            chaincodes: chaincodes,
            cryptoType: cryptoType,
            isEthereum: ethereumBased,
            seedSource: seedSource
        )

        let address = ethereumBased
            ? try keypair.publicKey.ethereumAddressFromPublicKey()
            : try keypair.publicKey.publicKeyToAccountId()

        return AccountQuery(
            publicKey: keypair.publicKey,
            privateKey: keypair.secretKey,
            address: address,
            seed: seed
        )
    }

    func createMetaAccount(
        name: String,
        substratePublicKey: Data,
        substrateCryptoType: CryptoType,
        ethereumPublicKey: Data?,
        isBackuped: Bool,
        defaultChainId: ChainModel.Id? = nil
    ) throws -> MetaAccountModel {
        let substrateAccountId = try substratePublicKey.publicKeyToAccountId()
        let ethereumAddress = try ethereumPublicKey?.ethereumAddressFromPublicKey()

        return MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType.rawValue,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: [],
            assetKeysOrder: nil,
            assetFilterOptions: [],
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: defaultChainId,
            assetsVisibility: [],
            zeroBalanceAssetsHidden: false,
            hasBackup: isBackuped,
            favouriteChainIds: []
        )
    }
}

// MARK: - MetaAccountOperationFactoryProtocol

extension MetaAccountOperationFactory: MetaAccountOperationFactoryProtocol {
    public func newMetaAccountOperation(
        mnemonicRequest: MetaAccountImportMnemonicRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let substrateQuery = try getQuery(
                seedSource: .mnemonic(mnemonicRequest.mnemonic),
                derivationPath: mnemonicRequest.substrateDerivationPath,
                cryptoType: mnemonicRequest.cryptoType,
                ethereumBased: false
            )

            let ethereumQuery = try getQuery(
                seedSource: .mnemonic(mnemonicRequest.mnemonic),
                derivationPath: mnemonicRequest.ethereumDerivationPath,
                cryptoType: .ecdsa,
                ethereumBased: true
            )

            let metaAccount = try createMetaAccount(
                name: mnemonicRequest.username,
                substratePublicKey: substrateQuery.publicKey,
                substrateCryptoType: mnemonicRequest.cryptoType,
                ethereumPublicKey: ethereumQuery.publicKey,
                isBackuped: isBackuped,
                defaultChainId: mnemonicRequest.defaultChainId
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(
                mnemonicRequest.substrateDerivationPath,
                metaId: metaId,
                ethereumBased: false
            )
            try saveSeed(substrateQuery.seed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumQuery.privateKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(
                mnemonicRequest.ethereumDerivationPath,
                metaId: metaId,
                ethereumBased: true
            )
            try saveSeed(ethereumQuery.privateKey, metaId: metaId, ethereumBased: true)

            try saveEntropy(mnemonicRequest.mnemonic.entropy(), metaId: metaId)

            return metaAccount
        }
    }

    //  We use seed vs seed.miniSeed for mnemonic. Check if it works for SeedRequest.
    public func newMetaAccountOperation(
        seedRequest: MetaAccountImportSeedRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let substrateSeed = try Data(hexStringSSF: seedRequest.substrateSeed)
            let substrateQuery = try getQuery(
                seedSource: .seed(substrateSeed),
                derivationPath: seedRequest.substrateDerivationPath,
                cryptoType: seedRequest.cryptoType,
                ethereumBased: false
            )

            var ethereumQuery: AccountQuery?
            if let ethereumSeedString = seedRequest.ethereumSeed,
               let ethereumSeed = try? Data(hexStringSSF: ethereumSeedString),
               let ethereumDerivationPath = seedRequest.ethereumDerivationPath
            {
                ethereumQuery = try getQuery(
                    seedSource: .seed(ethereumSeed),
                    derivationPath: ethereumDerivationPath,
                    cryptoType: .ecdsa,
                    ethereumBased: true
                )
            }

            let metaAccount = try createMetaAccount(
                name: seedRequest.username,
                substratePublicKey: substrateQuery.publicKey,
                substrateCryptoType: seedRequest.cryptoType,
                ethereumPublicKey: ethereumQuery?.publicKey,
                isBackuped: isBackuped
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(
                seedRequest.substrateDerivationPath,
                metaId: metaId,
                ethereumBased: false
            )
            try saveSeed(substrateQuery.seed, metaId: metaId, ethereumBased: false)

            if let query = ethereumQuery, let derivationPath = seedRequest.ethereumDerivationPath {
                try saveSecretKey(query.privateKey, metaId: metaId, ethereumBased: true)
                try saveDerivationPath(derivationPath, metaId: metaId, ethereumBased: true)
                try saveSeed(query.privateKey, metaId: metaId, ethereumBased: true)
            }

            return metaAccount
        }
    }

    public func newMetaAccountOperation(
        keystoreRequest: MetaAccountImportKeystoreRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            guard let substrateData = keystoreRequest.substrateKeystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let substrateKeystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: substrateData
            )

            guard let substrateKeystore = try? keystoreExtractor
                .extractFromDefinition(
                    substrateKeystoreDefinition,
                    password: keystoreRequest.substratePassword
                ) else
            {
                throw AccountOperationFactoryError.decryption
            }

            let substratePublicKey: IRPublicKeyProtocol

            switch keystoreRequest.cryptoType {
            case .sr25519:
                substratePublicKey = try SNPublicKey(rawData: substrateKeystore.publicKeyData)
            case .ed25519:
                substratePublicKey = try EDPublicKey(rawData: substrateKeystore.publicKeyData)
            case .ecdsa:
                substratePublicKey = try SECPublicKey(rawData: substrateKeystore.publicKeyData)
            }

            var ethereumKeystore: KeystoreData?
            var ethereumPublicKey: IRPublicKeyProtocol?
            var ethereumAddress: Data?
            if let ethereumDataString = keystoreRequest.ethereumKeystore,
               let ethereumData = ethereumDataString.data(using: .utf8)
            {
                let ethereumKeystoreDefinition = try JSONDecoder().decode(
                    KeystoreDefinition.self,
                    from: ethereumData
                )

                ethereumKeystore = try? keystoreExtractor
                    .extractFromDefinition(
                        ethereumKeystoreDefinition,
                        password: keystoreRequest.ethereumPassword
                    )
                guard let keystore = ethereumKeystore else {
                    throw AccountOperationFactoryError.decryption
                }

                if let privateKey = try? SECPrivateKey(rawData: keystore.secretKeyData) {
                    ethereumPublicKey = try SECKeyFactory().derive(fromPrivateKey: privateKey)
                        .publicKey()
                    ethereumAddress = try ethereumPublicKey?.rawData()
                        .ethereumAddressFromPublicKey()
                }
            }

            let metaId = UUID().uuidString
            let accountId = try substratePublicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(substrateKeystore.secretKeyData, metaId: metaId, ethereumBased: false)
            if let ethereumKeystore = ethereumKeystore {
                try saveSecretKey(
                    ethereumKeystore.secretKeyData,
                    metaId: metaId,
                    ethereumBased: true
                )
            }

            return MetaAccountModel(
                metaId: metaId,
                name: keystoreRequest.username,
                substrateAccountId: accountId,
                substrateCryptoType: keystoreRequest.cryptoType.rawValue,
                substratePublicKey: substratePublicKey.rawData(),
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumPublicKey?.rawData(),
                chainAccounts: [],
                assetKeysOrder: nil,
                assetFilterOptions: [],
                canExportEthereumMnemonic: true,
                unusedChainIds: nil,
                selectedCurrency: Currency.defaultCurrency(),
                networkManagmentFilter: nil,
                assetsVisibility: [],
                zeroBalanceAssetsHidden: false,
                hasBackup: isBackuped,
                favouriteChainIds: []
            )
        }
    }

    public func importChainAccountOperation(mnemonicRequest: ChainAccountImportMnemonicRequest)
        -> BaseOperation<MetaAccountModel>
    {
        ClosureOperation { [self] in
            let query = try getQuery(
                seedSource: .mnemonic(mnemonicRequest.mnemonic),
                derivationPath: mnemonicRequest.derivationPath,
                cryptoType: mnemonicRequest.cryptoType,
                ethereumBased: mnemonicRequest.isEthereum
            )

            let metaId = mnemonicRequest.meta.metaId
            let accountId = mnemonicRequest.isEthereum ?
                try query.publicKey.ethereumAddressFromPublicKey() : try query.publicKey
                .publicKeyToAccountId()

            try saveSecretKey(
                query.privateKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: mnemonicRequest.isEthereum
            )

            try saveDerivationPath(
                mnemonicRequest.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: mnemonicRequest.isEthereum
            )

            try saveSeed(
                query.seed,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: mnemonicRequest.isEthereum
            )
            try saveEntropy(
                mnemonicRequest.mnemonic.entropy(),
                metaId: metaId,
                accountId: accountId
            )

            let chainAccount = ChainAccountModel(
                chainId: mnemonicRequest.chainId,
                accountId: accountId,
                publicKey: query.publicKey,
                cryptoType: mnemonicRequest.cryptoType.rawValue,
                ethereumBased: mnemonicRequest.isEthereum
            )

            return mnemonicRequest.meta.insertingChainAccount(chainAccount)
        }
    }

    public func importChainAccountOperation(seedRequest: ChainAccountImportSeedRequest)
        -> BaseOperation<MetaAccountModel>
    {
        ClosureOperation { [self] in
            let seed = try Data(hexStringSSF: seedRequest.seed)
            let query = try getQuery(
                seedSource: .seed(seed),
                derivationPath: seedRequest.derivationPath,
                cryptoType: seedRequest.cryptoType,
                ethereumBased: seedRequest.isEthereum
            )
            let accountId = seedRequest.isEthereum ?
                try query.publicKey.ethereumAddressFromPublicKey() : try query.publicKey
                .publicKeyToAccountId()
            let metaId = seedRequest.meta.metaId

            try saveSecretKey(
                query.privateKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: seedRequest.isEthereum
            )

            try saveDerivationPath(
                seedRequest.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: seedRequest.isEthereum
            )

            try saveSeed(
                seed,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: seedRequest.isEthereum
            )

            let chainAccount = ChainAccountModel(
                chainId: seedRequest.chainId,
                accountId: accountId,
                publicKey: query.publicKey,
                cryptoType: seedRequest.cryptoType.rawValue,
                ethereumBased: seedRequest.isEthereum
            )

            return seedRequest.meta.insertingChainAccount(chainAccount)
        }
    }

    public func importChainAccountOperation(keystoreRequest: ChainAccountImportKeystoreRequest)
        -> BaseOperation<MetaAccountModel>
    {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            guard let data = keystoreRequest.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: data
            )

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: keystoreRequest.password) else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol
            if keystoreRequest.isEthereum {
                if let privateKey = try? SECPrivateKey(rawData: keystore.secretKeyData) {
                    publicKey = try SECKeyFactory().derive(fromPrivateKey: privateKey).publicKey()
                } else {
                    throw AccountOperationFactoryError.decryption
                }
            } else {
                switch keystoreRequest.cryptoType {
                case .sr25519:
                    publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
                case .ed25519:
                    publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
                case .ecdsa:
                    publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
                }
            }
            let accountId = keystoreRequest.isEthereum ?
                try publicKey.rawData().ethereumAddressFromPublicKey() : try publicKey.rawData()
                .publicKeyToAccountId()

            try saveSecretKey(
                keystore.secretKeyData,
                metaId: keystoreRequest.meta.metaId,
                accountId: accountId,
                ethereumBased: keystoreRequest.isEthereum
            )

            let chainAccount = ChainAccountModel(
                chainId: keystoreRequest.chainId,
                accountId: accountId,
                publicKey: publicKey.rawData(),
                cryptoType: keystoreRequest.cryptoType.rawValue,
                ethereumBased: keystoreRequest.isEthereum
            )

            return keystoreRequest.meta.insertingChainAccount(chainAccount)
        }
    }
}
