import UIKit
import IrohaCrypto
import RobinHood

final class AccountCreateInteractor {
    weak var presenter: AccountCreateInteractorOutputProtocol!

    let mnemonicCreator: IRMnemonicCreatorProtocol

    init(
        mnemonicCreator: IRMnemonicCreatorProtocol
    ) {
        self.mnemonicCreator = mnemonicCreator
    }
}

extension AccountCreateInteractor: AccountCreateInteractorInputProtocol {
    func setup() {
        do {
            let mnemonic = try mnemonicCreator.randomMnemonic(.entropy128)

            presenter.didReceive(mnemonic: mnemonic.allWords())
        } catch {
            presenter.didReceiveMnemonicGeneration(error: error)
        }
    }
}
