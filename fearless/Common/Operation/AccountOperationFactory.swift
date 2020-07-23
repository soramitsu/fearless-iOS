import Foundation
import FearlessUtils
import IrohaCrypto
import RobinHood
import SoraKeystore

protocol AccountOperationFactoryProtocol {
    func newAccountOperation(addressType: SNAddressType,
                             password: String,
                             strength: IRMnemonicStrength) -> BaseOperation<Void>

    func deriveAccountOperation(addressType: SNAddressType,
                                mnemonic: String,
                                password: String) -> BaseOperation<Void>
}

extension AccountOperationFactoryProtocol {
    func newAccountOperation(addressType: SNAddressType,
                             password: String) -> BaseOperation<Void> {
        newAccountOperation(addressType: addressType, password: password, strength: .entropy128)
    }

    func newAccountOperation(addressType: SNAddressType) -> BaseOperation<Void> {
        newAccountOperation(addressType: addressType, password: "", strength: .entropy128)
    }

    func deriveAccountOperation(addressType: SNAddressType, mnemonic: String) -> BaseOperation<Void> {
        deriveAccountOperation(addressType: addressType, mnemonic: mnemonic, password: "")
    }
}

final class AccountOperationFactory: AccountOperationFactoryProtocol {
    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol

    private lazy var keypairFactory: SNKeyFactoryProtocol = SNKeyFactory()
    private lazy var addressFactory: SS58AddressFactoryProtocol = SS58AddressFactory()
    private lazy var seedFactory: SeedFactoryProtocol = SeedFactory()

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    func newAccountOperation(addressType: SNAddressType,
                             password: String,
                             strength: IRMnemonicStrength) -> BaseOperation<Void> {
        ClosureOperation {
            let result = try self.seedFactory.createSeed(from: password, strength: strength)
            try self.save(addressType: addressType, result: result)
        }
    }

    func deriveAccountOperation(addressType: SNAddressType,
                                mnemonic: String,
                                password: String) -> BaseOperation<Void> {
        ClosureOperation {
            let result = try self.seedFactory.deriveSeed(from: mnemonic, password: password)
            try self.save(addressType: addressType, result: result)
        }
    }

    private func save(addressType: SNAddressType, result: SeedFactoryResult) throws {
        let keypair = try keypairFactory.createKeypair(fromSeed: result.seed)
        let address = try addressFactory.address(from: keypair.publicKey(), type: addressType)

        settings.selectedAccount = AccountItem(address: address, cryptoType: .sr25519)

        try keystore.saveSeed(result.seed, address: address)
        try keystore.saveEntropy(result.mnemonic.entropy(), address: address)
    }
}
