import UIKit
import IrohaCrypto

final class ExportMnemonicConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    let mnemonic: IRMnemonicProtocol
    let shuffledWords: [String]

    init(mnemonic: IRMnemonicProtocol) {
        self.mnemonic = mnemonic
        self.shuffledWords = mnemonic.allWords().shuffled()
    }
}

extension ExportMnemonicConfirmInteractor: AccountConfirmInteractorInputProtocol {
    func requestWords() {
        presenter.didReceive(words: shuffledWords, afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        guard words == mnemonic.allWords() else {
            presenter.didReceive(words: shuffledWords,
                                 afterConfirmationFail: true)
            return
        }

        presenter.didCompleteConfirmation()
    }

    func skipConfirmation() {
        presenter.didCompleteConfirmation()
    }
}
