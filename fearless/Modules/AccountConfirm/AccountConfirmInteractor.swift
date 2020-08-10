import UIKit
import SoraKeystore
import IrohaCrypto

final class AccountConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let keychain: KeystoreProtocol
    let settings: SettingsManagerProtocol

    init(keychain: KeystoreProtocol, settings: SettingsManagerProtocol) {
        self.keychain = keychain
        self.settings = settings
    }

    private func fetchEntropy() throws -> Data {
        guard let selectedAccount = settings.selectedAccount else {
            throw AccountConfirmError.missingAccount
        }

        guard let entropy = try keychain.fetchEntropyForAddress(selectedAccount.address) else {
            throw AccountConfirmError.missingEntropy
        }

        return entropy
    }

    private func provideWords(afterConfirmationFail: Bool) {
        do {
            let entropy = try fetchEntropy()
            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)
            let words = mnemonic.allWords().shuffled()

            presenter.didReceive(words: words, afterConfirmationFail: afterConfirmationFail)
        } catch {
            presenter.didReceive(error: error)
        }
    }
}

extension AccountConfirmInteractor: AccountConfirmInteractorInputProtocol {
    func requestWords() {
        provideWords(afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        do {
            let entropy = try fetchEntropy()

            let mnemonic = try IRMnemonicCreator().mnemonic(fromEntropy: entropy)

            if words == mnemonic.allWords() {
                presenter.didCompleteConfirmation()
            } else {
                provideWords(afterConfirmationFail: true)
            }
        } catch {
            presenter.didReceive(error: error)
        }
    }
}
