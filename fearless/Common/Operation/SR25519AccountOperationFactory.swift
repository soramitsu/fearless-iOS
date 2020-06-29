import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood

final class SR25519AccountOperationFactory: AccountOperationFactoryProtocol {
    private(set) var keystore: KeystoreProtocol
    private(set) var settings: SettingsManagerProtocol

    private lazy var keypairFactory: SR25519KeypairFactoryProtocol = SR25519KeypairFactory()

    init(keystore: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keystore = keystore
        self.settings = settings
    }

    func newAccountOperation(password: String, strength: IRMnemonicStrength) -> BaseOperation<Void> {
        ClosureOperation {
            let result = try self.keypairFactory.createKeypair(from: password, strength: strength)
            try self.save(result: result)
        }
    }

    func deriveAccountOperation(mnemonic: String, password: String) -> BaseOperation<Void> {
        ClosureOperation {
            let result = try self.keypairFactory.deriveKeypair(from: mnemonic, password: password)
            try self.save(result: result)
        }
    }

    private func save(result: SR25519KeypairResult) throws {
        try keystore.saveKey(result.keypair.rawData(), with: KeystoreKey.privateKey.rawValue)
        try keystore.saveKey(result.mnemonic.entropy(), with: KeystoreKey.seedEntropy.rawValue)

        settings.accountId = result.keypair.publicKey().rawData()
    }
}
