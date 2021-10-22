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
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    // MARK: - Factory functions

    private func createKeypairFactory(_ cryptoType: MultiassetCryptoType) -> KeypairFactoryProtocol {
        switch cryptoType {
        case .sr25519:
            return SR25519KeypairFactory()
        case .ed25519:
            return Ed25519KeypairFactory()
        case .substrateEcdsa:
            return EcdsaKeypairFactory()
        case .ethereumEcdsa:
            return BIP32KeypairFactory()
        }
    }

    // MARK: - Derivation functions

    private func getJunctionResult(
        from derivationPath: String,
        ethereumBased: Bool
    ) throws -> JunctionResult? {
        guard !derivationPath.isEmpty else { return nil }

        let junctionFactory = ethereumBased ?
            BIP32JunctionFactory() : SubstrateJunctionFactory()

        return try junctionFactory.parse(path: derivationPath)
    }

    private func deriveSeed(
        from mnemonic: String,
        password: String,
        ethereumBased: Bool
    ) throws -> SeedFactoryResult {
        let seedFactory: SeedFactoryProtocol = ethereumBased ?
            BIP32SeedFactory() : SeedFactory()

        return try seedFactory.deriveSeed(from: mnemonic, password: password)
    }

    // MARK: - Save functions

    private func saveSecretKey(
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

    private func saveEntropy(
        _ entropy: Data,
        metaId: String,
        accountId: AccountId? = nil
    ) throws {
        let tag = KeystoreTagV2.entropyTagForMetaId(metaId, accountId: accountId)
        try keystore.saveKey(entropy, with: tag)
    }

    private func saveDerivationPath(
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

    private func saveSeed(
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
        cryptoType: MultiassetCryptoType
    ) throws -> (publicKey: Data, secretKey: Data) {
        let keypairFactory = createKeypairFactory(cryptoType)

        let keypair = try keypairFactory.createKeypairFromSeed(
            seed,
            chaincodeList: chaincodes
        )

        switch cryptoType {
        case .sr25519, .ethereumEcdsa:
            return (
                publicKey: keypair.publicKey().rawData(),
                secretKey: keypair.privateKey().rawData()
            )
        case .ed25519, .substrateEcdsa:
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

    private func prepopulateMetaAccount(
        name: String,
        publicKey: Data,
        cryptoType: MultiassetCryptoType
    ) throws -> MetaAccountModel {
        guard cryptoType != .ethereumEcdsa else {
            throw AccountCreationError.unsupportedNetwork
        }

        let accountId = try publicKey.publicKeyToAccountId()

        return MetaAccountModel(
            metaId: UUID().uuidString,
            name: name,
            substrateAccountId: accountId,
            substrateCryptoType: cryptoType.rawValue,
            substratePublicKey: publicKey,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
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
            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: false
            )

            let password = junctionResult?.password ?? ""
            let chaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(
                from: mnemonic.toString(),
                password: password,
                ethereumBased: false
            )

            let substrateKeypair = try generateKeypair(
                from: seedResult.seed.miniSeed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let metaAccount = try prepopulateMetaAccount(
                name: request.username,
                publicKey: substrateKeypair.publicKey,
                cryptoType: request.cryptoType
            )

            let ethereumDerivationPath = DerivationPathConstants.defaultEthereum

            let ethereumJunctionResult = try getJunctionResult(
                from: ethereumDerivationPath,
                ethereumBased: true
            )

            let ethereumChaincodes = ethereumJunctionResult?.chaincodes ?? []

            let ethereumSeedFactory = BIP32SeedFactory()
            let ethereumSeedResult = try ethereumSeedFactory.deriveSeed(
                from: mnemonic.toString(),
                password: password
            )

            let keypairFactory = createKeypairFactory(.ethereumEcdsa)

            let ethereumKeypair = try keypairFactory.createKeypairFromSeed(
                ethereumSeedResult.seed,
                chaincodeList: ethereumChaincodes
            )

            let ethereumSecretKey = ethereumKeypair.privateKey().rawData()
            let ethereumPublicKey = ethereumKeypair.publicKey().rawData()
            let ethereumAddress = try ethereumPublicKey.ethereumAddressFromPublicKey()

            let metaId = metaAccount.metaId

            try saveSecretKey(substrateKeypair.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(seedResult.seed.miniSeed, metaId: metaId, ethereumBased: false)

            try saveSecretKey(ethereumSecretKey, metaId: metaId, ethereumBased: true)
            try saveDerivationPath(ethereumDerivationPath, metaId: metaId, ethereumBased: true)
            try saveSeed(ethereumSeedResult.seed, metaId: metaId, ethereumBased: true)

            try saveEntropy(mnemonic.entropy(), metaId: metaId)

            return metaAccount
                .replacingEthereumPublicKey(ethereumPublicKey)
                .replacingEthereumAddress(ethereumAddress)
        }
    }

    func newMetaAccountOperation(request: MetaAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation { [self] in
            let junctionResult = try getJunctionResult(
                from: request.derivationPath,
                ethereumBased: false
            )

            let chaincodes = junctionResult?.chaincodes ?? []
            let seed = try Data(hexString: request.seed)

            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let metaAccount = try prepopulateMetaAccount(
                name: request.username,
                publicKey: keypair.publicKey,
                cryptoType: request.cryptoType
            )

            let metaId = metaAccount.metaId

            try saveSecretKey(keypair.secretKey, metaId: metaId, ethereumBased: false)
            try saveDerivationPath(request.derivationPath, metaId: metaId, ethereumBased: false)
            try saveSeed(seed, metaId: metaId, ethereumBased: false)

            return metaAccount
        }
    }

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
            case .substrateEcdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            case .ethereumEcdsa:
                throw AccountCreationError.unsupportedNetwork
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
            let ethereumBased = request.cryptoType == .ethereumEcdsa

            let junctionResult = try getJunctionResult(from: request.derivationPath, ethereumBased: ethereumBased)

            let password = junctionResult?.password ?? ""
            let chaincodes = junctionResult?.chaincodes ?? []

            let seedResult = try self.deriveSeed(
                from: request.mnemonic,
                password: password,
                ethereumBased: false
            )

            let seed = ethereumBased ? seedResult.seed : seedResult.seed.miniSeed
            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let publicKey = keypair.publicKey
            let accountId = try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

            try saveSecretKey(
                keypair.secretKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveSeed(seed, metaId: metaId, accountId: accountId, ethereumBased: ethereumBased)
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
            let ethereumBased = request.cryptoType == .ethereumEcdsa

            let junctionResult = try getJunctionResult(from: request.derivationPath, ethereumBased: ethereumBased)

            let chaincodes = junctionResult?.chaincodes ?? []

            let seed = try Data(hexString: request.seed)

            let keypair = try generateKeypair(
                from: seed,
                chaincodes: chaincodes,
                cryptoType: request.cryptoType
            )

            let publicKey = keypair.publicKey
            let accountId = try publicKey.publicKeyToAccountId()
            let metaId = metaAccount.metaId

            try saveSecretKey(
                keypair.secretKey,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveDerivationPath(
                request.derivationPath,
                metaId: metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
            )

            try saveSeed(seed, metaId: metaId, accountId: accountId, ethereumBased: ethereumBased)

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

            let ethereumBased = request.cryptoType == .ethereumEcdsa

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
            case .substrateEcdsa, .ethereumEcdsa:
                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
            }

            let metaId = UUID().uuidString
            let accountId = try publicKey.rawData().publicKeyToAccountId()

            try saveSecretKey(
                keystore.secretKeyData,
                metaId: metaAccount.metaId,
                accountId: accountId,
                ethereumBased: ethereumBased
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
