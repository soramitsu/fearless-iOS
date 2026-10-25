import IrohaCrypto
import UIKit

final class ExportMnemonicConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    private let mnemonic: IRMnemonicProtocol
    private let shuffledWords: [String]
    private let settings: SelectedWalletSettings
    private let wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol
    private let recordsWholeWalletBackup: Bool
    private var saving = false
    private var completed = false

    init(
        mnemonic: IRMnemonicProtocol,
        settings: SelectedWalletSettings,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol,
        recordsWholeWalletBackup: Bool
    ) {
        self.mnemonic = mnemonic
        self.settings = settings
        self.wallet = wallet
        self.eventCenter = eventCenter
        self.recordsWholeWalletBackup = recordsWholeWalletBackup
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
        guard !saving, !completed else { return }
        guard words == mnemonic.allWords() else {
            presenter.didReceive(
                words: shuffledWords,
                afterConfirmationFail: true
            )
            return
        }

        guard recordsWholeWalletBackup else {
            completed = true
            presenter.didCompleteConfirmation()
            return
        }
        saving = true
        let output = presenter
        let events = eventCenter
        settings.recordBackup(of: wallet) { [weak self, weak output] result in
            self?.saving = false
            switch result {
            case let .success(savedWallet):
                self?.completed = true
                events.notify(with: MetaAccountModelChangedEvent(account: savedWallet))
                guard let self, self.presenter === output else { return }
                output?.didCompleteConfirmation()
            case let .failure(error):
                guard let self, self.presenter === output else { return }
                output?.didReceive(error: error)
            }
        }
    }

    func skipConfirmation() {
        guard !saving, !completed else { return }
        completed = true
        presenter.didCompleteConfirmation()
    }
}
