import UIKit
import IrohaCrypto
import SSFModels

final class ExportMnemonicConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    private let mnemonic: [String]
    private let shuffledWords: [String]
    private let settings: SelectedWalletSettings
    private let wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol

    init(
        mnemonic: [String],
        settings: SelectedWalletSettings,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol
    ) {
        self.mnemonic = mnemonic
        self.settings = settings
        self.wallet = wallet
        self.eventCenter = eventCenter
        shuffledWords = mnemonic.shuffled()
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
        guard words == mnemonic else {
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
