import Foundation

struct SignerConfirmViewFactory {
    static func createView(from request: SignerOperationRequestProtocol) -> SignerConfirmViewProtocol? {
        let interactor = SignerConfirmInteractor()
        let wireframe = SignerConfirmWireframe()

        let presenter = SignerConfirmPresenter(interactor: interactor, wireframe: wireframe)

        let view = SignerConfirmViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
