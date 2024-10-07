import Foundation
import SSFAccountManagment
import SSFUtils
import IrohaCrypto
import RobinHood
import SoraKeystore
import SSFModels
import SSFCrypto
import TonSwift

protocol MetaAccountOperationFactoryProtocol {
    func newTonMetaAccountOperation(
        request: MetaAccountImportTonMnemonicRequest,
        isBackedUp: Bool
    ) -> BaseOperation<SSFModels.MetaAccountModel>
    func newMetaAccountOperation(
        request: MetaAccountImportMnemonicRequest,
        isBackedUp: Bool
    ) -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(
        request: MetaAccountImportSeedRequest,
        isBackedUp: Bool
    ) -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(
        request: MetaAccountImportKeystoreRequest,
        isBackedUp: Bool
    ) -> BaseOperation<MetaAccountModel>

    func importChainAccountOperation(
        request: ChainAccountImportMnemonicRequest
    ) -> BaseOperation<MetaAccountModel>
    func importChainAccountOperation(
        request: ChainAccountImportSeedRequest
    ) -> BaseOperation<MetaAccountModel>
    func importChainAccountOperation(
        request: ChainAccountImportKeystoreRequest
    ) -> BaseOperation<MetaAccountModel>
}

final class MetaAccountOperationFactory {
    private struct AccountQuery {
        let publicKey: Data
        let privateKey: Data
        let address: Data
        let seed: Data
    }

    private struct TonAccountQuery {
        let publicKey: Data
        let privateKey: Data
        let address: TonSwift.Address
        let seed: Data
        let contractVersion: TonContractVersion
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
        ecosystem: Ecosystem,
        accountId: AccountId? = nil
    ) throws {
        let tag = KeystoreTagV2.secretKeyTag(for: ecosystem, metaId: metaId, accountId: accountId)
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
        ecosystem: Ecosystem,
        accountId: AccountId? = nil
    ) throws {
        let tag = KeystoreTagV2.seedKeyTag(for: ecosystem, metaId: metaId, accountId: accountId)
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

    private func getTonQuery(
        mnemonic: String
    ) throws -> TonAccountQuery {
        let mnemonicArray = mnemonic.components(separatedBy: " ")
        let seed = Mnemonic.mnemonicToSeed(mnemonicArray: mnemonicArray)
        let keypair = try Mnemonic.mnemonicToPrivateKey(mnemonicArray: mnemonicArray)

        /// Currently support version 4 revision 2
        /// Do not forget to change contractVersion if will support v5 contract
        let wallet = WalletV4R2(publicKey: keypair.publicKey.data)
        let address = try wallet.address()

        return TonAccountQuery(
            publicKey: keypair.publicKey.data,
            privateKey: keypair.privateKey.data,
            address: address,
            seed: seed,
            contractVersion: .v4R2
        )
    }

    func createMetaAccount(
        name: String,
        ecosystem: WalletEcosystem,
        isBackedUp: Bool,
        defaultChainId: ChainModel.Id? = nil,
        assetsVisibility: [AssetVisibility] = []
    ) throws -> MetaAccountModel {
        return MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            ecosystem: ecosystem,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: true,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: defaultChainId,
            assetsVisibility: assetsVisibility,
            hasBackup: isBackedUp,
            favouriteChainIds: []
        )
    }
}

// MARK: - MetaAccountOperationFactoryProtocol

extension MetaAccountOperationFactory: MetaAccountOperationFactoryProtocol {
    func newTonMetaAccountOperation(
        request: MetaAccountImportTonMnemonicRequest,
        isBackedUp: Bool
    ) -> BaseOperation<SSFModels.MetaAccountModel> {
        ClosureOperation { [self] in
            let tonQuery = try getTonQuery(mnemonic: request.mnemonic)
            let ecosystem = WalletEcosystem.ton(.init(
                tonAddress: tonQuery.address,
                tonPublicKey: tonQuery.publicKey,
                tonContractVersion: tonQuery.contractVersion
            ))
            let metaAccount = try createMetaAccount(
                name: request.username,
                ecosystem: ecosystem,
                isBackedUp: isBackedUp,
                defaultChainId: "-239",
                assetsVisibility: [.init(
                    assetId: ["-239", "2ba4723a-74b4-4a6f-a888-e51937773807-239"].joined(separator: " : "),
                    hidden: false
                )]
            )

            let metaId = metaAccount.metaId
            try saveSecretKey(tonQuery.privateKey, metaId: metaId, ecosystem: .ton)
            guard let data = request.mnemonic.data(using: .utf8) else {
                throw AccountCreateError.invalidMnemonicFormat
            }
            try saveEntropy(data, metaId: metaId)

            return metaAccount
        }
    }

    func newMetaAccountOperation(
        request: MetaAccountImportMnemonicRequest,
        isBackedUp: Bool
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

            let substrateAccountId = try substrateQuery.publicKey.publicKeyToAccountId()
            let ethereumAddress = try ethereumQuery.publicKey.ethereumAddressFromPublicKey()
            let ecosystem = WalletEcosystem.regular(.init(
                substrateAccountId: substrateAccountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: substrateQuery.publicKey,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumQuery.publicKey
            ))

            let metaAccount = try createMetaAccount(
                name: request.username,
                ecosystem: ecosystem,
                isBackedUp: isBackedUp,
                defaultChainId: request.defaultChainId
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ecosystem: .substrate)
            try saveDerivationPath(request.substrateDerivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(substrateQuery.seed, metaId: metaId, ecosystem: .substrate)

            try saveSecretKey(ethereumQuery.privateKey, metaId: metaId, ecosystem: .ethereumBased)
            try saveDerivationPath(request.ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(ethereumQuery.privateKey, metaId: metaId, ecosystem: .ethereumBased)

            try saveEntropy(request.mnemonic.entropy(), metaId: metaId)

            return metaAccount
        }
    }

    //  We use seed vs seed.miniSeed for mnemonic. Check if it works for SeedRequest.
    func newMetaAccountOperation(
        request: MetaAccountImportSeedRequest,
        isBackedUp: Bool
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

            let substrateAccountId = try substrateQuery.publicKey.publicKeyToAccountId()
            let ethereumAddress = try ethereumQuery?.publicKey.ethereumAddressFromPublicKey()
            let ecosystem = WalletEcosystem.regular(.init(
                substrateAccountId: substrateAccountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: substrateQuery.publicKey,
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumQuery?.publicKey
            ))
            let metaAccount = try createMetaAccount(
                name: request.username,
                ecosystem: ecosystem,
                isBackedUp: isBackedUp
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ecosystem: .substrate)
            try saveDerivationPath(request.substrateDerivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(substrateQuery.seed, metaId: metaId, ecosystem: .substrate)

            if let query = ethereumQuery, let derivationPath = request.ethereumDerivationPath {
                try saveSecretKey(query.privateKey, metaId: metaId, ecosystem: .ethereumBased)
                try saveDerivationPath(derivationPath, metaId: metaId, ethereumBased: true)
                try saveSeed(query.privateKey, metaId: metaId, ecosystem: .ethereumBased)
            }

            return metaAccount
        }
    }

    func newMetaAccountOperation(
        request: MetaAccountImportKeystoreRequest,
        isBackedUp: Bool
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

            try saveSecretKey(substrateKeystore.secretKeyData, metaId: metaId, ecosystem: .substrate)
            if let ethereumKeystore = ethereumKeystore {
                try saveSecretKey(ethereumKeystore.secretKeyData, metaId: metaId, ecosystem: .ethereumBased)
            }

            let ecosystem = WalletEcosystem.regular(.init(
                substrateAccountId: accountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: substratePublicKey.rawData(),
                ethereumAddress: ethereumAddress,
                ethereumPublicKey: ethereumPublicKey?.rawData()
            ))
            return MetaAccountModel(
                metaId: metaId,
                name: request.username,
                ecosystem: ecosystem,
                chainAccounts: [],
                assetKeysOrder: nil,
                canExportEthereumMnemonic: true,
                unusedChainIds: nil,
                selectedCurrency: Currency.defaultCurrency(),
                networkManagmentFilter: nil,
                assetsVisibility: [],
                hasBackup: isBackedUp,
                favouriteChainIds: []
            )
        }
    }

    func importChainAccountOperation(request: ChainAccountImportMnemonicRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let metaId = request.meta.metaId

            let accountId: AccountId
            let privateKey: Data
            let publicKey: Data
            switch request.ecosystem {
            case .substrate:
                let query = try getQuery(
                    seedSource: .mnemonic(request.mnemonic),
                    derivationPath: request.derivationPath,
                    cryptoType: request.cryptoType,
                    ethereumBased: false
                )
                accountId = try query.publicKey.publicKeyToAccountId()
                privateKey = query.privateKey
                publicKey = query.publicKey
                try saveSeed(query.seed, metaId: metaId, ecosystem: request.ecosystem)
            case .ethereum, .ethereumBased:
                let query = try getQuery(
                    seedSource: .mnemonic(request.mnemonic),
                    derivationPath: request.derivationPath,
                    cryptoType: request.cryptoType,
                    ethereumBased: true
                )
                accountId = try query.publicKey.ethereumAddressFromPublicKey()
                privateKey = query.privateKey
                publicKey = query.publicKey
                try saveSeed(query.seed, metaId: metaId, ecosystem: request.ecosystem)
            case .ton:
                throw AccountOperationFactoryError.unsupportedImport
            }

            try saveSecretKey(
                privateKey,
                metaId: metaId,
                ecosystem: request.ecosystem,
                accountId: accountId
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: request.ecosystem.isEthereum || request.ecosystem.isEthereumBased
            )

            try saveEntropy(request.mnemonic.entropy(), metaId: metaId, accountId: accountId)

            let chainAccount = ChainAccountModel(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue,
                ecosystem: request.ecosystem
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
                ethereumBased: request.ecosystem.isEthereum || request.ecosystem.isEthereumBased
            )

            let accountId: AccountId
            switch request.ecosystem {
            case .substrate:
                accountId = try query.publicKey.publicKeyToAccountId()
            case .ethereum, .ethereumBased:
                accountId = try query.publicKey.ethereumAddressFromPublicKey()
            case .ton:
                throw AccountOperationFactoryError.unsupportedImport
            }
            let metaId = request.meta.metaId

            try saveSecretKey(
                query.privateKey,
                metaId: metaId,
                ecosystem: request.ecosystem,
                accountId: accountId
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: request.ecosystem.isEthereum || request.ecosystem.isEthereumBased
            )

            try saveSeed(seed, metaId: metaId, ecosystem: request.ecosystem)

            let chainAccount = ChainAccountModel(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: query.publicKey,
                cryptoType: request.cryptoType.rawValue,
                ecosystem: request.ecosystem
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
                .extractFromDefinition(keystoreDefinition, password: request.password) else {
                throw AccountOperationFactoryError.decryption
            }

            let publicKey: IRPublicKeyProtocol
            let accountId: Data
            switch request.ecosystem {
            case .substrate:
                switch request.cryptoType {
                case .sr25519:
                    publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
                case .ed25519:
                    publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
                case .ecdsa:
                    publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
                }
                accountId = try publicKey.rawData().publicKeyToAccountId()
            case .ethereum, .ethereumBased:
                if let privateKey = try? SECPrivateKey(rawData: keystore.secretKeyData) {
                    publicKey = try SECKeyFactory().derive(fromPrivateKey: privateKey).publicKey()
                } else {
                    throw AccountOperationFactoryError.decryption
                }
                accountId = try publicKey.rawData().ethereumAddressFromPublicKey()
            case .ton:
                throw AccountOperationFactoryError.unsupportedImport
            }

            try saveSecretKey(
                keystore.secretKeyData,
                metaId: request.meta.metaId,
                ecosystem: request.ecosystem,
                accountId: accountId
            )

            let chainAccount = ChainAccountModel(
                chainId: request.chainId,
                accountId: accountId,
                publicKey: publicKey.rawData(),
                cryptoType: request.cryptoType.rawValue,
                ecosystem: request.ecosystem
            )

            return request.meta.insertingChainAccount(chainAccount)
        }
    }
}
