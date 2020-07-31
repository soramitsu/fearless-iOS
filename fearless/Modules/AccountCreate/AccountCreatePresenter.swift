import Foundation

final class AccountCreatePresenter {
    weak var view: AccountCreateViewProtocol?
    var wireframe: AccountCreateWireframeProtocol!
    var interactor: AccountCreateInteractorInputProtocol!
}

extension AccountCreatePresenter: AccountCreatePresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func selectCryptoType() {

    }

    func selectNetworkType() {

    }

    func proceed() {

    }
}

extension AccountCreatePresenter: AccountCreateInteractorOutputProtocol {
    func didReceive(metadata: AccountCreationMetadata) {
        view?.set(mnemonic: metadata.mnemonic)
    }

    func didReceiveMnemonicGeneration(error: Error) {

    }

    func didCompleteAccountCreation() {

    }

    func didReceiveAccountCreation(error: Error) {}
}
