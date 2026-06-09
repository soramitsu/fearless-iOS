import UIKit
import IrohaCrypto

final class ExportMnemonicConfirmInteractor {
    weak var presenter: AccountConfirmInteractorOutputProtocol!

    private let mnemonics: [IRMnemonicProtocol]
    private let shuffledWords: [[String]]
    private let settings: SelectedWalletSettings
    private let wallet: MetaAccountModel
    private let eventCenter: EventCenterProtocol

    private var currentMnemonicIndex = 0

    init(
        mnemonics: [IRMnemonicProtocol],
        settings: SelectedWalletSettings,
        wallet: MetaAccountModel,
        eventCenter: EventCenterProtocol
    ) {
        self.mnemonics = mnemonics
        self.settings = settings
        self.wallet = wallet
        self.eventCenter = eventCenter
        shuffledWords = mnemonics.map { $0.allWords().shuffled() }
    }
}

extension ExportMnemonicConfirmInteractor: AccountConfirmInteractorInputProtocol {
    var flow: AccountConfirmFlow? {
        nil
    }

    func requestWords() {
        presenter.didReceive(words: currentShuffledWords, afterConfirmationFail: false)
    }

    func confirm(words: [String]) {
        guard let mnemonic = currentMnemonic else {
            presenter.didReceive(error: CommonError.undefined)
            return
        }

        guard words == mnemonic.allWords() else {
            presenter.didReceive(
                words: currentShuffledWords,
                afterConfirmationFail: true
            )
            return
        }

        guard currentMnemonicIndex == mnemonics.count - 1 else {
            currentMnemonicIndex += 1
            presenter.didReceive(words: currentShuffledWords, afterConfirmationFail: false)
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

private extension ExportMnemonicConfirmInteractor {
    var currentMnemonic: IRMnemonicProtocol? {
        guard mnemonics.indices.contains(currentMnemonicIndex) else {
            return nil
        }

        return mnemonics[currentMnemonicIndex]
    }

    var currentShuffledWords: [String] {
        guard shuffledWords.indices.contains(currentMnemonicIndex) else {
            return []
        }

        return shuffledWords[currentMnemonicIndex]
    }
}
