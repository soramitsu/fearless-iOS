import Foundation

struct ManageAssetsViewFactory {
    static func createView() -> ManageAssetsViewProtocol? {
        let interactor = ManageAssetsInteractor()
        let wireframe = ManageAssetsWireframe()

        let presenter = ManageAssetsPresenter(interactor: interactor, wireframe: wireframe)

        let view = ManageAssetsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}