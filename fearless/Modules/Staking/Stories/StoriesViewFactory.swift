import Foundation
import SoraFoundation

final class StoriesViewFactory: StoriesViewFactoryProtocol {
    static func createView(with index: Int) -> StoriesViewProtocol? {
        // MARK: - View

        let view = StoriesViewController(nib: R.nib.storiesViewController)
        view.localizationManager = LocalizationManager.shared

        // MARK: - Interactor

        let interactor = StoriesInteractor(model: StoriesFactory.createModel())

        // MARK: - Presenter

        let viewModelFactory = StoriesViewModelFactory()
        let presenter = StoriesPresenter(
            selectedStoryIndex: index,
            viewModelFactory: viewModelFactory
        )

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
