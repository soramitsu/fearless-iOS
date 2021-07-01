import Foundation
import SoraFoundation

struct ExperimentalListViewFactory {
    static func createView() -> ExperimentalListViewProtocol? {
        let interactor = ExperimentalListInteractor()
        let wireframe = ExperimentalListWireframe()

        let presenter = ExperimentalListPresenter(interactor: interactor, wireframe: wireframe)

        let view = ExperimentalListViewController(presenter: presenter, localizationManager: LocalizationManager.shared)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
