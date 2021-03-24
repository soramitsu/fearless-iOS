import Foundation
import SoraFoundation

final class StoriesViewFactory: StoriesViewFactoryProtocol {
    static func createView() -> StoriesViewProtocol? {

        // MARK: - View
        let view = StoriesViewController(nib: R.nib.storiesViewController)
        view.localizationManager = LocalizationManager.shared

        // MARK: - Interactor
        let interactor = StoriesInteractor()

        // MARK: - Presenter
        // Create View Model Factory here
        // let viewModelFactory = ...

        // And pass it to the initializer
        let presenter = StoriesPresenter()

        // MARK: - Router
        let wireframe = StoriesWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
