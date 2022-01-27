import Foundation
import SoraFoundation

struct FiltersViewFactory {
    static func createView(filters: [FilterSet], moduleOutput: FiltersModuleOutput?) -> FiltersViewProtocol? {
        let interactor = FiltersInteractor(filters: filters)
        let wireframe = FiltersWireframe()

        let viewModelFactory: FiltersViewModelFactoryProtocol = FiltersViewModelFactory()
        let presenter = FiltersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            moduleOutput: moduleOutput,
            localizationManager: LocalizationManager.shared
        )

        let view = FiltersViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
