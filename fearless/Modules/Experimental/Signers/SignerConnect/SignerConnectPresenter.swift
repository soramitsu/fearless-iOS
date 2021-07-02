import Foundation

final class SignerConnectPresenter {
    weak var view: SignerConnectViewProtocol?
    let wireframe: SignerConnectWireframeProtocol
    let interactor: SignerConnectInteractorInputProtocol

    init(
        interactor: SignerConnectInteractorInputProtocol,
        wireframe: SignerConnectWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SignerConnectPresenter: SignerConnectPresenterProtocol {
    func setup() {}
}

extension SignerConnectPresenter: SignerConnectInteractorOutputProtocol {}
