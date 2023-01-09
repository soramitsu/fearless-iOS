import Foundation
import SoraFoundation

final class StoriesViewFactory: StoriesViewFactoryProtocol {
    static func createView(with index: Int, chainAsset: ChainAsset) -> StoriesViewProtocol? {
        // MARK: - View

        let view = StoriesViewController(nib: R.nib.storiesViewController)
        let localizationManager = LocalizationManager.shared
        view.localizationManager = localizationManager

        // MARK: - Interactor

        let factory = StoriesFactory()
        guard let storiesModel = factory.createModel(for: chainAsset.stakingType)?.value(for: localizationManager.selectedLocale) else {
            return nil
        }
        let interactor = StoriesInteractor(model: storiesModel)

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
