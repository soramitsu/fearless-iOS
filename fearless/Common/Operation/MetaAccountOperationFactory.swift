import Foundation
import SSFUtils
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels

protocol MetaAccountOperationFactoryProtocol {
    func newMetaAccountOperation(request: MetaAccountImportMnemonicRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(request: MetaAccountImportSeedRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(request: MetaAccountImportKeystoreRequest, isBackuped: Bool) -> BaseOperation<MetaAccountModel>

    func importChainAccountOperation(request: ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel>
    func importChainAccountOperation(request: ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel>
    func importChainAccountOperation(request: ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel>
}

final class MetaAccountOperationFactory {
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

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }
}

private extension MetaAccountOperationFactory {
    // MARK: - Factory functions

    func createKeypairFactory(_ cryptoType: CryptoType, isEthereumBased: Bool) -> KeypairFactoryProtocol {
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
              let derivationPathData = derivationPath.asSecretData()
        else { return }

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

            return (
                publicKey: try SECKeyFactory().derive(fromPrivateKey: privateKey).publicKey().rawData(),
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
    func newMetaAccountOperation(
        request: MetaAccountImportMnemonicRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let substrateQuery = try getQuery(
                seedSource: .mnemonic(request.mnemonic),
                derivationPath: request.substrateDerivationPath,
                cryptoType: request.cryptoType,
                ethereumBased: false
            )

            let ethereumQuery = try getQuery(
                seedSource: .mnemonic(request.mnemonic),
                derivationPath: request.ethereumDerivationPath,
                cryptoType: .ecdsa,
                ethereumBased: true
            )

            let metaAccount = try createMetaAccount(
                name: request.username,
                substratePublicKey: substrateQuery.publicKey,
                substrateCryptoType: request.cryptoType,
                ethereumPublicKey: ethereumQuery.publicKey,
                isBackuped: isBackuped,
                defaultChainId: request.defaultChainId
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.substrateDerivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(substrateQuery.seed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumQuery.privateKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(request.ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(ethereumQuery.privateKey, metaId: metaId, ethereumBased: true)

            try saveEntropy(request.mnemonic.entropy(), metaId: metaId)

            return metaAccount
        }
    }

    //  We use seed vs seed.miniSeed for mnemonic. Check if it works for SeedRequest.
    func newMetaAccountOperation(
        request: MetaAccountImportSeedRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let substrateSeed = try Data(hexStringSSF: request.substrateSeed)
            let substrateQuery = try getQuery(
                seedSource: .seed(substrateSeed),
                derivationPath: request.substrateDerivationPath,
                cryptoType: request.cryptoType,
                ethereumBased: false
            )

            var ethereumQuery: AccountQuery?
            if let ethereumSeedString = request.ethereumSeed,
               let ethereumSeed = try? Data(hexStringSSF: ethereumSeedString),
               let ethereumDerivationPath = request.ethereumDerivationPath {
                ethereumQuery = try getQuery(
                    seedSource: .seed(ethereumSeed),
                    derivationPath: ethereumDerivationPath,
                    cryptoType: .ecdsa,
                    ethereumBased: true
                )
            }

            let metaAccount = try createMetaAccount(
                name: request.username,
                substratePublicKey: substrateQuery.publicKey,
                substrateCryptoType: request.cryptoType,
                ethereumPublicKey: ethereumQuery?.publicKey,
                isBackuped: isBackuped
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.substrateDerivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(substrateQuery.seed, metaId: metaId, ethereumBased: false)

            if let query = ethereumQuery, let derivationPath = request.ethereumDerivationPath {
                try saveSecretKey(query.privateKey, metaId: metaId, ethereumBased: true)
                try saveDerivationPath(derivationPath, metaId: metaId, ethereumBased: true)
                try saveSeed(query.privateKey, metaId: metaId, ethereumBased: true)
            }

            return metaAccount
        }
    }

    func newMetaAccountOperation(
        request: MetaAccountImportKeystoreRequest,
        isBackuped: Bool
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            guard let substrateData = request.substrateKeystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let substrateKeystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: substrateData
            )

            guard let substrateKeystore = try? keystoreExtractor
                .extractFromDefinition(substrateKeystoreDefinition, password: request.substratePassword)
            else {
                throw AccountOperationFactoryError.decryption
            }

            let substratePublicKey: IRPublicKeyProtocol

            switch request.cryptoType {
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
            if let ethereumDataString = request.ethereumKeystore,
               let ethereumData = ethereumDataString.data(using: .utf8) {
                let ethereumKeystoreDefinition = try JSONDecoder().decode(
                    KeystoreDefinition.self,
                    from: ethereumData
                )

                ethereumKeystore = try? keystoreExtractor
                    .extractFromDefinition(ethereumKeystoreDefinition, password: request.ethereumPassword)
                guard let keystore = ethereumKeystore else {
                    throw AccountOperationFactoryError.decryption
                }

                if let privateKey = try? SECPrivateKey(rawData: keystore.secretKeyData) {
                    ethereumPublicKey = try SECKeyFactory().derive(fromPrivateKey: privateKey).publicKey()
                    ethereumAddress = try ethereumPublicKey?.rawData().ethereumAddressFromPublicKey()
                }
            }

            let metaId = UUID().uuidString
            let accountId = try substratePublicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(substrateKeystore.secretKeyData, metaId: metaId, ethereumBased: false)
            if let ethereumKeystore = ethereumKeystore {
                try saveSecretKey(ethereumKeystore.secretKeyData, metaId: metaId, ethereumBased: true)
            }

            return MetaAccountModel(
                metaId: metaId,
                name: request.username,
                substrateAccountId: accountId,
                substrateCryptoType: request.cryptoType.rawValue,
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

    func importChainAccountOperation(request: ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let query = try getQuery(
                seedSource: .mnemonic(request.mnemonic),
                derivationPath: request.derivationPath,
                cryptoType: request.cryptoType,
                ethereumBased: request.isEthereum
            )

            let metaId = request.meta.metaId
            let accountId = request.isEthereum ?
                try query.publicKey.ethereumAddressFromPublicKey() : try query.publicKey.publicKeyToAccountId()

            try saveSecretKey(
                query.privateKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: request.isEthereum
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: request.isEthereum
            )

            try saveSeed(query.seed, metaId: metaId, accountId: accountId, ethereumBased: request.isEthereum)
            try saveEntropy(request.mnemonic.entropy(), metaId: metaId, accountId: accountId)

            let chainAccount = ChainAccountModel(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: query.publicKey,
                cryptoType: request.cryptoType.rawValue,
                ethereumBased: request.isEthereum
            )

            return request.meta.insertingChainAccount(chainAccount)
        }
    }

    func importChainAccountOperation(request: ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let seed = try Data(hexStringSSF: request.seed)
            let query = try getQuery(
                seedSource: .seed(seed),
                derivationPath: request.derivationPath,
                cryptoType: request.cryptoType,
                ethereumBased: request.isEthereum
            )
            let accountId = request.isEthereum ?
                try query.publicKey.ethereumAddressFromPublicKey() : try query.publicKey.publicKeyToAccountId()
            let metaId = request.meta.metaId

            try saveSecretKey(
                query.privateKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: request.isEthereum
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: request.isEthereum
            )

            try saveSeed(seed, metaId: metaId, accountId: accountId, ethereumBased: request.isEthereum)

            let chainAccount = ChainAccountModel(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: query.publicKey,
                cryptoType: request.cryptoType.rawValue,
                ethereumBased: request.isEthereum
            )

            return request.meta.insertingChainAccount(chainAccount)
        }
    }

    func importChainAccountOperation(request: ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let keystoreExtractor = KeystoreExtractor()

            guard let data = request.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(
                KeystoreDefinition.self,
                from: data
            )

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: request.password)
            else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol
            if request.isEthereum {
                if let privateKey = try? SECPrivateKey(rawData: keystore.secretKeyData) {
                    publicKey = try SECKeyFactory().derive(fromPrivateKey: privateKey).publicKey()
                } else {
                    throw AccountOperationFactoryError.decryption
                }
            } else {
                switch request.cryptoType {
                case .sr25519:
                    publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
                case .ed25519:
                    publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
                case .ecdsa:
                    publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
                }
            }
            let accountId = request.isEthereum ?
                try publicKey.rawData().ethereumAddressFromPublicKey() : try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(
                keystore.secretKeyData,
                metaId: request.meta.metaId,
                accountId: accountId,
                ethereumBased: request.isEthereum
            )

            let chainAccount = ChainAccountModel(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey.rawData(),
                cryptoType: request.cryptoType.rawValue,
                ethereumBased: request.isEthereum
            )

            return request.meta.insertingChainAccount(chainAccount)
        }
    }
}
