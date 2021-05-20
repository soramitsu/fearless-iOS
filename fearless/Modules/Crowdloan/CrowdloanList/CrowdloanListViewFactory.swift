import Foundation

struct CrowdloanListViewFactory {
    static func createView() -> CrowdloanListViewProtocol? {
        let interactor = CrowdloanListInteractor()
        let wireframe = CrowdloanListWireframe()

        let presenter = CrowdloanListPresenter(interactor: interactor, wireframe: wireframe)

        let view = CrowdloanListViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
