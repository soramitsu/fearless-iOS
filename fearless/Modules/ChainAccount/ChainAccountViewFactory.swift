import Foundation

struct ChainAccountViewFactory {
    static func createView() -> ChainAccountViewProtocol? {
        let interactor = ChainAccountInteractor()
        let wireframe = ChainAccountWireframe()

        let presenter = ChainAccountPresenter(interactor: interactor, wireframe: wireframe)

        let view = ChainAccountViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
