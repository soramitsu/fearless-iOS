import UIKit
import IrohaCrypto

final class ExportMnemonicConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    private let mnemonic: IRMnemonicProtocol
    private let shuffledWords: [String]
    private let settings: SelectedWalletSettings
    private let wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol

    init(
        mnemonic: IRMnemonicProtocol,
        settings: SelectedWalletSettings,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol
    ) {
        self.mnemonic = mnemonic
        self.settings = settings
        self.wallet = wallet
        self.eventCenter = eventCenter
        shuffledWords = mnemonic.allWords().shuffled()
    }
}

extension ExportMnemonicConfirmInteractor: AccountConfirmInteractorInputProtocol {
    var flow: AccountConfirmFlow? {
        nil
    }

    func requestWords() {
        presenter.didReceive(words: shuffledWords, afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        guard words == mnemonic.allWords() else {
            presenter.didReceive(
                words: shuffledWords,
                afterConfirmationFail: true
            )
            return
        }

        let backupedWallet = wallet.replacingIsBackuped(true)
        settings.save(value: backupedWallet)
        let event = MetaAccountModelChangedEvent(account: backupedWallet)
        eventCenter.notify(with: event)

        presenter.didCompleteConfirmation()
    }

    func skipConfirmation() {
        presenter.didCompleteConfirmation()
    }
}
