import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import SoraKeystore

protocol MetaAccountOperationFactoryProtocol {
    func newMetaAccountOperation(request: MetaAccountCreationRequest, mnemonic: IRMnemonicProtocol)
        -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(request: MetaAccountImportSeedRequest) -> BaseOperation<MetaAccountModel>
    func newMetaAccountOperation(request: MetaAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel>

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportMnemonicRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel>

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportSeedRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel>

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportKeystoreRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel>
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
        switch cryptoType {
        case .sr25519:
            return SR25519KeypairFactory()
        case .ed25519:
            return Ed25519KeypairFactory()
        case .ecdsa:
            if isEthereumBased {
                return BIP32KeypairFactory()
            }
            return EcdsaKeypairFactory()
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

    func generateKeypair(
        from seed: Data,
        chaincodes: [Chaincode],
        cryptoType: CryptoType,
        isEthereum: Bool
    ) throws -> (publicKey: Data, secretKey: Data) {
        let keypairFactory = createKeypairFactory(cryptoType, isEthereumBased: isEthereum)

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: chaincodes
        )

        if isEthereum || cryptoType == .sr25519 {
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
                ethereumBased: false
            )

            seed = ethereumBased ? seedResult.seed : seedResult.seed.miniSeed
        case let .seed(data):
            seed = data
        }

        let keypair = try generateKeypair(
            from: seed,
            chaincodes: chaincodes,
            cryptoType: cryptoType,
            isEthereum: ethereumBased
        )

        let address = ethereumBased ?
            try keypair.publicKey.ethereumAddressFromPublicKey() :
            try keypair.publicKey.publicKeyToAccountId()

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
        ethereumPublicKey: Data
    ) throws -> MetaAccountModel {
        let substrateAccountId = try substratePublicKey.publicKeyToAccountId()
        let ethereumAddress = try ethereumPublicKey.ethereumAddressFromPublicKey()

        return MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: substrateAccountId,
            substrateCryptoType: substrateCryptoType.rawValue,
            substratePublicKey: substratePublicKey,
            ethereumAddress: ethereumAddress,
            ethereumPublicKey: ethereumPublicKey,
            chainAccounts: []
        )
    }
}

// MARK: - MetaAccountOperationFactoryProtocol

extension MetaAccountOperationFactory: MetaAccountOperationFactoryProtocol {
    func newMetaAccountOperation(
        request: MetaAccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let substrateQuery = try getQuery(
                seedSource: .mnemonic(mnemonic),
                derivationPath: request.substrateDerivationPath,
                cryptoType: request.substrateCryptoType,
                ethereumBased: false
            )

            let ethereumQuery = try getQuery(
                seedSource: .mnemonic(mnemonic),
                derivationPath: request.ethereumDerivationPath,
                cryptoType: .ecdsa,
                ethereumBased: true
            )

            let metaAccount = try createMetaAccount(
                name: request.username,
                substratePublicKey: substrateQuery.publicKey,
                substrateCryptoType: request.substrateCryptoType,
                ethereumPublicKey: ethereumQuery.publicKey
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.substrateDerivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(substrateQuery.seed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumQuery.privateKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(request.ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(ethereumQuery.seed, metaId: metaId, ethereumBased: true)

            try saveEntropy(mnemonic.entropy(), metaId: metaId)

            return metaAccount
        }
    }

    //  We use seed vs seed.miniSeed for mnemonic. Check if it works for SeedRequest.
    func newMetaAccountOperation(request: MetaAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let seed = try Data(hexString: request.seed)
            let substrateQuery = try getQuery(
                seedSource: .seed(seed),
                derivationPath: request.substrateDerivationPath,
                cryptoType: request.cryptoType,
                ethereumBased: false
            )

            let ethereumQuery = try getQuery(
                seedSource: .seed(seed),
                derivationPath: request.ethereumDerivationPath,
                cryptoType: .ecdsa,
                ethereumBased: true
            )

            let metaAccount = try createMetaAccount(
                name: request.username,
                substratePublicKey: substrateQuery.publicKey,
                substrateCryptoType: request.cryptoType,
                ethereumPublicKey: ethereumQuery.publicKey
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateQuery.privateKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.substrateDerivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(substrateQuery.seed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumQuery.privateKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(request.ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(ethereumQuery.seed, metaId: metaId, ethereumBased: true)

            return metaAccount
        }
    }

    //  TODO: Support ethereum json
    func newMetaAccountOperation(request: MetaAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
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

            switch request.cryptoType {
            case .sr25519:
                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
            case .ed25519:
                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
            case .ecdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            }

            let metaId = UUID().uuidString
            let accountId = try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(keystore.secretKeyData, metaId: metaId, ethereumBased: false)

            return MetaAccountModel(
                metaId: metaId,
                name: request.username,
                substrateAccountId: accountId,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: publicKey.rawData(),
                ethereumAddress: nil,
                ethereumPublicKey: nil,
                chainAccounts: []
            )
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportMnemonicRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: request.isEthereum
            )

            let password = junctionResult?.password ?? ""
            let chaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(
                from: request.mnemonic,
                password: password,
                ethereumBased: request.isEthereum
            )

            let seed = request.isEthereum ? seedResult.seed : seedResult.seed.miniSeed
            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType,
                isEthereum: request.isEthereum
            )

            let publicKey = keypair.publicKey
            let accountId = request.isEthereum ? try publicKey.ethereumAddressFromPublicKey() :
                try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

            try saveSecretKey(
                keypair.secretKey,
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
            try saveEntropy(seedResult.mnemonic.entropy(), metaId: metaId)

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportSeedRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: request.isEthereum
            )

            let chaincodes = junctionResult?.chaincodes ?? []

            let seed = try Data(hexString: request.seed)

            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType,
                isEthereum: request.isEthereum
            )

            let publicKey = keypair.publicKey
            let accountId = request.isEthereum ? try publicKey.ethereumAddressFromPublicKey() :
                try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

            try saveSecretKey(
                keypair.secretKey,
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
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey,
                cryptoType: request.cryptoType.rawValue
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportKeystoreRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
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

            switch request.cryptoType {
            case .sr25519:
                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
            case .ed25519:
                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
            case .ecdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            }

            let metaId = UUID().uuidString
            let accountId = request.isEthereum ?
                try publicKey.rawData().ethereumAddressFromPublicKey() :
                try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(
                keystore.secretKeyData,
                metaId: metaAccount.metaId,
                accountId: accountId,
                ethereumBased: request.isEthereum
            )

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: accountId,
                publicKey: publicKey.rawData(),
                cryptoType: request.cryptoType.rawValue
            )

            try self.saveSecretKey(keystore.secretKeyData, metaId: metaId, ethereumBased: false)

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }
}
