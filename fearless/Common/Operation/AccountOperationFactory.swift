import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import SoraKeystore

protocol AccountOperationFactoryProtocol {
    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol) -> BaseOperation<AccountItem>

    func newAccountOperation(request: AccountImportSeedRequest) -> BaseOperation<AccountItem>

    func newAccountOperation(request: AccountImportKeystoreRequest) -> BaseOperation<AccountItem>
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    private(set) var keystore: KeystoreProtocol

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol) -> BaseOperation<AccountItem> {
        ClosureOperation {
            let junctionResult: JunctionResult?

            if !request.derivationPath.isEmpty {
                let junctionFactory = JunctionFactory()
                junctionResult = try junctionFactory.parse(path: request.derivationPath)
            } else {
                junctionResult = nil
            }

            let password = junctionResult?.password ?? ""

            let seedFactory = SeedFactory()
            let result = try seedFactory.deriveSeed(from: mnemonic.toString(),
                                                    password: password)

            let keypairFactory = self.createKeypairFactory(request.cryptoType)

            let chaincodes = junctionResult?.chaincodes ?? []
            let keypair = try keypairFactory.createKeypairFromSeed(result.seed.miniSeed,
                                                                   chaincodeList: chaincodes)

            let addressFactory = SS58AddressFactory()
            let address = try addressFactory.address(fromPublicKey: keypair.publicKey(),
                                                     type: SNAddressType(chain: request.type))

            let secretKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(result.seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            case .ecdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(result.seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            }

            try self.keystore.saveSecretKey(secretKey, address: address)
            try self.keystore.saveEntropy(result.mnemonic.entropy(), address: address)

            if !request.derivationPath.isEmpty {
                try self.keystore.saveDeriviation(request.derivationPath, address: address)
            }

            try self.keystore.saveSeed(result.seed.miniSeed, address: address)

            return AccountItem(address: address,
                               cryptoType: request.cryptoType,
                               username: request.username,
                               publicKeyData: keypair.publicKey().rawData())
        }
    }

    func newAccountOperation(request: AccountImportSeedRequest) -> BaseOperation<AccountItem> {
        ClosureOperation {
            let seed = try Data(hexString: request.seed)

            let junctionResult: JunctionResult?

            if !request.derivationPath.isEmpty {
                let junctionFactory = JunctionFactory()
                junctionResult = try junctionFactory.parse(path: request.derivationPath)
            } else {
                junctionResult = nil
            }

            let keypairFactory = self.createKeypairFactory(request.cryptoType)

            let chaincodes = junctionResult?.chaincodes ?? []
            let keypair = try keypairFactory.createKeypairFromSeed(seed,
                                                                   chaincodeList: chaincodes)

            let addressFactory = SS58AddressFactory()
            let address = try addressFactory.address(fromPublicKey: keypair.publicKey(),
                                                     type: SNAddressType(chain: request.networkType))

            let secretKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            case .ecdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(seed.miniSeed,
                                                                               chaincodeList: chaincodes)
            }

            try self.keystore.saveSecretKey(secretKey, address: address)

            if !request.derivationPath.isEmpty {
                try self.keystore.saveDeriviation(request.derivationPath, address: address)
            }

            try self.keystore.saveSeed(seed, address: address)

            return AccountItem(address: address,
                               cryptoType: request.cryptoType,
                               username: request.username,
                               publicKeyData: keypair.publicKey().rawData())
        }
    }

    func newAccountOperation(request: AccountImportKeystoreRequest) -> BaseOperation<AccountItem> {
        ClosureOperation {

            let keystoreExtractor = KeystoreExtractor()

            guard let data = request.keystore.data(using: .utf8) else {
                throw AccountOperationFactoryError.invalidKeystore
            }

            let keystoreDefinition = try JSONDecoder().decode(KeystoreDefinition.self,
                                                              from: data)

            guard let keystore = try? keystoreExtractor
                .extractFromDefinition(keystoreDefinition, password: request.password) else {
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

            let addressFactory = SS58AddressFactory()
            let address = try addressFactory.address(fromPublicKey: publicKey,
                                                     type: SNAddressType(chain: request.networkType))

            try self.keystore.saveSecretKey(keystore.secretKeyData, address: address)

            return AccountItem(address: address,
                               cryptoType: request.cryptoType,
                               username: request.username,
                               publicKeyData: keystore.publicKeyData)
        }
    }

    private func createKeypairFactory(_ cryptoType: CryptoType) -> KeypairFactoryProtocol {
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
