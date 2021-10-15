import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import SoraKeystore

protocol MetaAccountOperationFactoryProtocol {
    func newAccountOperation(
        request: MetaaccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<MetaAccountModel>

    func newAccountOperation(
        request: ChainAccountImportSeedRequest
    ) -> BaseOperation<MetaAccountModel>

    func newAccountOperation(
        request: ChainAccountImportKeystoreRequest
    ) -> BaseOperation<MetaAccountModel>

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

extension MetaAccountOperationFactoryProtocol {
    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request _: ChainAccountImportSeedRequest,
        chainId _: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        BaseOperation.createWithResult(metaAccount)
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request _: ChainAccountImportKeystoreRequest,
        chainId _: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        BaseOperation.createWithResult(metaAccount)
    }
}

final class MetaAccountOperationFactory: MetaAccountOperationFactoryProtocol {
    private let keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func newAccountOperation(
        request: MetaaccountCreationRequest,
        mnemonic: IRMnemonicProtocol
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let junctionResult: JunctionResult?
            let ethereumJunctionResult: JunctionResult?

            if !request.derivationPath.isEmpty {
                let junctionFactory = SubstrateJunctionFactory()
                let ethereumJunctionFactory = BIP32JunctionFactory()
                junctionResult = try junctionFactory.parse(path: request.derivationPath)
                ethereumJunctionResult = try ethereumJunctionFactory.parse(path: request.derivationPath)
            } else {
                junctionResult = nil
                ethereumJunctionResult = nil
            }

            let password = junctionResult?.password ?? ""

            let substrateSeedFactory = SeedFactory()
            let substrateSeedResult = try substrateSeedFactory.deriveSeed(
                from: mnemonic.toString(),
                password: password
            )

            let ethereumSeedFactory = BIP32SeedFactory()
            let ethereumSeedResult = try ethereumSeedFactory.deriveSeed(
                from: mnemonic.toString(),
                password: password
            )

            let keypairFactory = self.createKeypairFactory(request.cryptoType)

            let chaincodes = junctionResult?.chaincodes ?? []
            let ethereumChaincodes = ethereumJunctionResult?.chaincodes ?? []

            let keypair = try keypairFactory.createKeypairFromSeed(
                substrateSeedResult.seed.miniSeed,
                chaincodeList: chaincodes
            )

            let secretKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(
                    substrateSeedResult.seed.miniSeed,
                    chaincodeList: chaincodes
                )
            // TODO: Refactor
            case .substrateEcdsa, .ethereumEcdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(
                    substrateSeedResult.seed.miniSeed,
                    chaincodeList: chaincodes
                )
            }

            let derivableSeedFactory = BIP32KeypairFactory()
            let ethereumKeypair = try derivableSeedFactory.createKeypairFromSeed(ethereumSeedResult.seed, chaincodeList: ethereumChaincodes)
            let ethereumSecretKey = ethereumKeypair.privateKey().rawData()

            let metaId = UUID().uuidString

            // TODO: Save substrate data
            // TODO: Save secret key
            try self.keystore.saveKey(
                secretKey,
                with: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId)
            )

            // TODO: Save entropy
            try self.keystore.saveKey(
                substrateSeedResult.mnemonic.entropy(),
                with: KeystoreTagV2.entropyTagForMetaId(metaId)
            )

            // TODO: Save derivationPath
            // TODO: Check correctness
            if !request.derivationPath.isEmpty {
                try self.keystore.saveKey(
                    request.derivationPath.asSecretData()!,
                    with: KeystoreTagV2.substrateDerivationTagForMetaId(metaId)
                )
            }

            // TODO: Save seed
            try self.keystore.saveKey(
                substrateSeedResult.seed.miniSeed,
                with: KeystoreTagV2.substrateSeedTagForMetaId(metaId)
            )

            // TODO: Save Ethereum data
            // TODO: Save secret key
            try self.keystore.saveKey(
                ethereumSecretKey,
                with: KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId)
            )

            // TODO: Save entropy
            // TODO: Check if the entropy is different from substrate
            try self.keystore.saveKey(
                ethereumSeedResult.mnemonic.entropy(),
                with: KeystoreTagV2.entropyTagForMetaId(metaId)
            )

            // TODO: Save derivationPath
            if !request.derivationPath.isEmpty {
                try self.keystore.saveKey(
                    request.derivationPath.asSecretData()!,
                    with: KeystoreTagV2.ethereumDerivationTagForMetaId(metaId)
                )
            }

            // TODO: Save seed
            try self.keystore.saveKey(
                ethereumSeedResult.seed,
                with: KeystoreTagV2.ethereumSeedTagForMetaId(metaId)
            )

            // TODO: 3. Return Meta account
            let metaAccount = MetaAccountModel(
                metaId: metaId,
                name: request.username,
                substrateAccountId: secretKey,
                substrateCryptoType: request.cryptoType.rawValue,
                substratePublicKey: keypair.publicKey().rawData(),
                ethereumAddress: nil, // TODO: derive address
                ethereumPublicKey: ethereumKeypair.publicKey().rawData(),
                chainAccounts: []
            )

            // TODO: generate chain accounts and replace them inside meta
            return metaAccount
        }
    }

    func newAccountOperation(request _: ChainAccountImportSeedRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            #error("Not implemented")
//            let seed = try Data(hexString: request.seed)
//
//            let junctionResult: JunctionResult?
//
//            if !request.derivationPath.isEmpty {
//                let junctionFactory = SubstrateJunctionFactory()
//                junctionResult = try junctionFactory.parse(path: request.derivationPath)
//            } else {
//                junctionResult = nil
//            }
//
//            let keypairFactory = self.createKeypairFactory(request.cryptoType)
//
//            let chaincodes = junctionResult?.chaincodes ?? []
//            let keypair = try keypairFactory.createKeypairFromSeed(
//                seed,
//                chaincodeList: chaincodes
//            )
//
//            let addressFactory = SS58AddressFactory()
//            let address = try addressFactory.address(
//                fromPublicKey: keypair.publicKey(),
//                type: SNAddressType(chain: request.networkType)
//            )
//
//            let secretKey: Data
//
//            switch request.cryptoType {
//            case .sr25519:
//                secretKey = keypair.privateKey().rawData()
//            case .ed25519:
//                let derivableSeedFactory = Ed25519KeypairFactory()
//                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(
//                    seed.miniSeed,
//                    chaincodeList: chaincodes
//                )
//            case .ecdsa:
//                let derivableSeedFactory = EcdsaKeypairFactory()
//                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(
//                    seed.miniSeed,
//                    chaincodeList: chaincodes
//                )
//            }
//
//            try self.keystore.saveSecretKey(secretKey, address: address)
//
//            if !request.derivationPath.isEmpty {
//                try self.keystore.saveDeriviation(request.derivationPath, address: address)
//            }
//
//            try self.keystore.saveSeed(seed, address: address)
//
//            return MetaAccountModel(
//                metaId: <#T##String#>,
//                name: <#T##String#>,
//                substrateAccountId: <#T##Data#>,
//                substrateCryptoType: <#T##UInt8#>,
//                substratePublicKey: <#T##Data#>,
//                ethereumAddress: <#T##Data?#>,
//                ethereumPublicKey: <#T##Data?#>,
//                chainAccounts: <#T##Set<ChainAccountModel>#>)
//
//            return AccountItem(
//                address: address,
//                cryptoType: request.cryptoType,
//                username: request.username,
//                publicKeyData: keypair.publicKey().rawData()
//            )
        }
    }

    func newAccountOperation(request _: ChainAccountImportKeystoreRequest) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            #error("Not implemented")
//            let keystoreExtractor = KeystoreExtractor()
//
//            guard let data = request.keystore.data(using: .utf8) else {
//                throw AccountOperationFactoryError.invalidKeystore
//            }
//
//            let keystoreDefinition = try JSONDecoder().decode(
//                KeystoreDefinition.self,
//                from: data
//            )
//
//            guard let keystore = try? keystoreExtractor
//                .extractFromDefinition(keystoreDefinition, password: request.password)
//            else {
//                throw AccountOperationFactoryError.decryption
//            }
//
//            let publicKey: IRPublicKeyProtocol
//
//            switch request.cryptoType {
//            case .sr25519:
//                publicKey = try SNPublicKey(rawData: keystore.publicKeyData)
//            case .ed25519:
//                publicKey = try EDPublicKey(rawData: keystore.publicKeyData)
//            case .ecdsa:
//                publicKey = try SECPublicKey(rawData: keystore.publicKeyData)
//            }
//
//            let addressFactory = SS58AddressFactory()
//            let address = try addressFactory.address(
//                fromPublicKey: publicKey,
//                type: SNAddressType(chain: request.networkType)
//            )
//
//            try self.keystore.saveSecretKey(keystore.secretKeyData, address: address)
//
//            return MetaAccountModel(
//                metaId: <#T##String#>,
//                name: <#T##String#>,
//                substrateAccountId: <#T##Data#>,
//                substrateCryptoType: <#T##UInt8#>,
//                substratePublicKey: <#T##Data#>,
//                ethereumAddress: <#T##Data?#>,
//                ethereumPublicKey: <#T##Data?#>,
//                chainAccounts: <#T##Set<ChainAccountModel>#>)
//
//            return AccountItem(
//                address: address,
//                cryptoType: request.cryptoType,
//                username: request.username,
//                publicKeyData: keystore.publicKeyData
//            )
        }
    }

    func replaceChainAccountOperation(
        for metaAccount: MetaAccountModel,
        request: ChainAccountImportMnemonicRequest,
        chainId: ChainModel.Id
    ) -> BaseOperation<MetaAccountModel> {
        ClosureOperation {
            let junctionResult: JunctionResult?
            let ethereumJunctionResult: JunctionResult?

            if !request.derivationPath.isEmpty {
                let junctionFactory = SubstrateJunctionFactory()
                let ethereumJunctionFactory = BIP32JunctionFactory()
                junctionResult = try junctionFactory.parse(path: request.derivationPath)
                ethereumJunctionResult = try ethereumJunctionFactory.parse(path: request.derivationPath)
            } else {
                junctionResult = nil
                ethereumJunctionResult = nil
            }

            let password = junctionResult?.password ?? ""

            let substrateSeedFactory = SeedFactory()
            let substrateSeedResult = try substrateSeedFactory.deriveSeed(
                from: request.mnemonic,
                password: password
            )

            let ethereumSeedFactory = BIP32SeedFactory()
            let ethereumSeedResult = try ethereumSeedFactory.deriveSeed(
                from: request.mnemonic,
                password: password
            )

            let chaincodes = junctionResult?.chaincodes ?? []
            let ethereumChaincodes = ethereumJunctionResult?.chaincodes ?? []

            let keypairFactory = self.createKeypairFactory(request.cryptoType)

            let keypair = try keypairFactory.createKeypairFromSeed(
                substrateSeedResult.seed.miniSeed,
                chaincodeList: chaincodes
            )

            let secretKey: Data
            let publicKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
                publicKey = keypair.publicKey().rawData()

            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(
                    substrateSeedResult.seed.miniSeed,
                    chaincodeList: chaincodes
                )

            case .substrateEcdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(
                    substrateSeedResult.seed.miniSeed,
                    chaincodeList: chaincodes
                )

            case .ethereumEcdsa:
                let derivableSeedFactory = BIP32KeypairFactory()
                let ethereumKeypair = try derivableSeedFactory.createKeypairFromSeed(ethereumSeedResult.seed, chaincodeList: ethereumChaincodes)
                secretKey = ethereumKeypair.privateKey().rawData()
            }

            try self.keystore.saveKey(secretKey, with: KeystoreTagV2.substrateSecretKeyTagForMetaId(metaAccount.identifier, accountId: secretKey))

            let chainAccount = ChainAccountModel(
                chainId: chainId,
                accountId: keypair.publicKey().rawData().getAccountIdFromKey(),
                publicKey: keypair.publicKey().rawData(),
                cryptoType: request.cryptoType.rawValue
            )

            return metaAccount.replacingChainAccount(chainAccount)
        }
    }

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
}
