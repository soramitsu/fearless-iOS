import Foundation

final class SignerConfirmPresenter {
    weak var view: SignerConfirmViewProtocol?
    let wireframe: SignerConfirmWireframeProtocol
    let interactor: SignerConfirmInteractorInputProtocol

    init(
        interactor: SignerConfirmInteractorInputProtocol,
        wireframe: SignerConfirmWireframeProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
    }
}

extension SignerConfirmPresenter: SignerConfirmPresenterProtocol {
    func setup() {}
}

extension SignerConfirmPresenter: SignerConfirmInteractorOutputProtocol {}