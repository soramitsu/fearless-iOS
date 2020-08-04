import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import SoraKeystore

protocol AccountOperationFactoryProtocol {
    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol) -> BaseOperation<Void>
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    func newAccountOperation(request: AccountCreationRequest,
                             mnemonic: IRMnemonicProtocol) -> BaseOperation<Void> {
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
            let keypair = try keypairFactory.createKeypairFromSeed(result.seed,
                                                                   chaincodeList: chaincodes)

            let addressFactory = SS58AddressFactory()
            let address = try addressFactory.address(fromPublicKey: keypair.publicKey(),
                                                     type: request.type)

            self.settings.selectedAccount = AccountItem(address: address,
                                                        cryptoType: request.cryptoType,
                                                        username: request.username,
                                                        publicKeyData: keypair.publicKey().rawData())

            try self.keystore.saveSeed(result.seed, address: address)
            try self.keystore.saveEntropy(result.mnemonic.entropy(), address: address)

            if !request.derivationPath.isEmpty {
                try self.keystore.saveDeriviation(request.derivationPath, address: address)
            }
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
