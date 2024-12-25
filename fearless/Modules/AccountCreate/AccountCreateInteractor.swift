import UIKit
import IrohaCrypto
import RobinHood
import TonSwift
import SSFModels

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let ecosystem: AccountCreateEcosystem
    let mnemonicCreator: IRMnemonicCreatorProtocol

    init(
        ecosystem: AccountCreateEcosystem,
        mnemonicCreator: IRMnemonicCreatorProtocol
    ) {
        self.ecosystem = ecosystem
        self.mnemonicCreator = mnemonicCreator
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        switch ecosystem {
        case .regular:
            do {
                let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)
                let allWords = mnemonic.allWords()
                presenter.didReceive(mnemonic: allWords)
            } catch {
                presenter.didReceiveMnemonicGeneration(error: error)
            }
        case .ton:
            let allWords = TonSwift.Mnemonic.mnemonicNew(wordsCount: 24)
            presenter.didReceive(mnemonic: allWords)
        }
    }

    func createMnemonicFromString(_ mnemonicString: String) -> IRMnemonicProtocol? {
        try? mnemonicCreator.mnemonic(fromList: mnemonicString)
    }
}
