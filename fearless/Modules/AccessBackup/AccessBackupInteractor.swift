import UIKit
import SoraKeystore
import IrohaCrypto

final class AccessBackupInteractor {
    weak var presenter: AccessBackupInteractorOutputProtocol?
    let keystore: KeystoreProtocol
    let settings: SettingsManagerProtocol
    let mnemonicCreator: IRMnemonicCreatorProtocol

    init(keystore: KeystoreProtocol,
         settings: SettingsManagerProtocol,
         mnemonicCreator: IRMnemonicCreatorProtocol) {
        self.keystore = keystore
        self.settings = settings
        self.mnemonicCreator = mnemonicCreator
    }

    private func loadPhrase() throws -> String {
        guard let accountItem = settings.selectedAccount else {
            throw AccessBackupInteractorError.missingSelectedAccount
        }

        guard let entropy = try keystore.fetchEntropyForAddress(accountItem.address) else {
            throw AccessBackupInteractorError.missingSelectedAccount
        }

        guard let mnemonic = try? mnemonicCreator.mnemonic(fromEntropy: entropy) else {
            throw AccessBackupInteractorError.mnemonicGenerationFailed
        }

        return mnemonic.toString()
    }
}

extension AccessBackupInteractor: AccessBackupInteractorInputProtocol {
    func load() {
        do {
            let mnemonic = try loadPhrase()
            presenter?.didLoad(mnemonic: mnemonic)
        } catch {
            presenter?.didReceive(error: error)
        }
    }
}
