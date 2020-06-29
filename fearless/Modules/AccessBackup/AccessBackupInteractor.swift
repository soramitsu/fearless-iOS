import UIKit
import SoraKeystore
import IrohaCrypto

final class AccessBackupInteractor {
    weak var presenter: AccessBackupInteractorOutputProtocol?
    let keystore: KeystoreProtocol
    let mnemonicCreator: IRMnemonicCreatorProtocol

    init(keystore: KeystoreProtocol, mnemonicCreator: IRMnemonicCreatorProtocol) {
        self.keystore = keystore
        self.mnemonicCreator = mnemonicCreator
    }

    private func loadPhrase() throws -> String {
        let entropy = try keystore.fetchKey(for: KeystoreKey.seedEntropy.rawValue)
        let mnemonic = try mnemonicCreator.mnemonic(fromEntropy: entropy)
        return mnemonic.toString()
    }
}

extension AccessBackupInteractor: AccessBackupInteractorInputProtocol {
    func load() {
        do {
            let mnemonic = try loadPhrase()
            presenter?.didLoad(mnemonic: mnemonic)
        } catch {
            presenter?.didReceive(error: AccessBackupInteractorError.loading)
        }
    }
}
