import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import SoraKeystore

protocol AccountOperationFactoryProtocol {
    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol,
                             connection: ConnectionItem?) -> BaseOperation<Void>

    func newAccountOperation(request: AccountImportSeedRequest,
                             connection: ConnectionItem?) -> BaseOperation<Void>

    func newAccountOperation(request: AccountImportKeystoreRequest,
                             connection: ConnectionItem?) -> BaseOperation<Void>
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol,
                             connection: ConnectionItem?) -> BaseOperation<Void> {
        ClosureOperation {
            guard let connection = connection ?? ConnectionItem.supportedConnections
                .first(where: { $0.type == request.type.rawValue}) else {
                throw AccountOperationFactoryError.unsupportedNetwork
            }

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
                                                     type: request.type)

            self.settings.selectedAccount = AccountItem(address: address,
                                                        cryptoType: request.cryptoType,
                                                        username: request.username,
                                                        publicKeyData: keypair.publicKey().rawData())

            let secretKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(result.seed,
                                                                               chaincodeList: chaincodes)
            case .ecdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(result.seed,
                                                                               chaincodeList: chaincodes)
            }

            try self.keystore.saveSecretKey(secretKey, address: address)
            try self.keystore.saveEntropy(result.mnemonic.entropy(), address: address)

            if !request.derivationPath.isEmpty {
                try self.keystore.saveDeriviation(request.derivationPath, address: address)
            }

            self.settings.selectedConnection = connection
        }
    }

    func newAccountOperation(request: AccountImportSeedRequest,
                             connection: ConnectionItem?) -> BaseOperation<Void> {
        ClosureOperation {
            let seed = try Data(hexString: request.seed)

            guard let connection = connection ?? ConnectionItem.supportedConnections
                .first(where: { $0.type == request.type.rawValue}) else {
                throw AccountOperationFactoryError.unsupportedNetwork
            }

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
                                                     type: request.type)

            self.settings.selectedAccount = AccountItem(address: address,
                                                        cryptoType: request.cryptoType,
                                                        username: request.username,
                                                        publicKeyData: keypair.publicKey().rawData())

            let secretKey: Data

            switch request.cryptoType {
            case .sr25519:
                secretKey = keypair.privateKey().rawData()
            case .ed25519:
                let derivableSeedFactory = Ed25519KeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(seed,
                                                                               chaincodeList: chaincodes)
            case .ecdsa:
                let derivableSeedFactory = EcdsaKeypairFactory()
                secretKey = try derivableSeedFactory.deriveChildSeedFromParent(seed,
                                                                               chaincodeList: chaincodes)
            }

            try self.keystore.saveSecretKey(secretKey, address: address)

            if !request.derivationPath.isEmpty {
                try self.keystore.saveDeriviation(request.derivationPath, address: address)
            }

            self.settings.selectedConnection = connection
        }
    }

    func newAccountOperation(request: AccountImportKeystoreRequest,
                             connection: ConnectionItem?) -> BaseOperation<Void> {
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

            let username: String

            if let requestName = request.username, !requestName.isEmpty {
                username = requestName
            } else {
                username = keystoreDefinition.meta.name
            }

            let addressFactory = SS58AddressFactory()
            let addressTypeValue = try addressFactory.type(fromAddress: keystore.address)

            guard let connection = connection ?? ConnectionItem.supportedConnections
                .first(where: { $0.type == addressTypeValue.uint8Value}) else {
                throw AccountOperationFactoryError.unsupportedNetwork
            }

            self.settings.selectedAccount = AccountItem(address: keystore.address,
                                                        cryptoType: CryptoType(keystore.cryptoType),
                                                        username: username,
                                                        publicKeyData: keystore.publicKeyData)

            try self.keystore.saveSecretKey(keystore.secretKeyData, address: keystore.address)

            self.settings.selectedConnection = connection
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
