import Foundation

struct ChainAccountBalanceListViewFactory {
    static func createView() -> ChainAccountBalanceListViewProtocol? {
        let interactor = ChainAccountBalanceListInteractor()
        let wireframe = ChainAccountBalanceListWireframe()

        let presenter = ChainAccountBalanceListPresenter(interactor: interactor, wireframe: wireframe)

        let view = ChainAccountBalanceListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
