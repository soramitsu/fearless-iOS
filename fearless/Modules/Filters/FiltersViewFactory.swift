import Foundation
import SoraUI
import SoraFoundation

enum FiltersMode {
    case singleSelection
    case multiSelection
}

enum FiltersViewFactory {
    static func createView(filters: [FilterSet], mode: FiltersMode = .multiSelection, moduleOutput: FiltersModuleOutput?) -> FiltersViewProtocol? {
        let interactor = FiltersInteractor(filters: filters)
        let wireframe = FiltersWireframe()

        let viewModelFactory: FiltersViewModelFactoryProtocol = FiltersViewModelFactory()
        let presenter = FiltersPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            moduleOutput: moduleOutput,
            mode: mode,
            localizationManager: LocalizationManager.shared
        )

        let view = FiltersViewController(presenter: presenter)

        view.modalPresentationStyle = .custom

        let transitionFactory = ModalSheetBlurPresentationFactory(configuration: ModalSheetPresentationConfiguration.fearlessBlur, shouldDissmissWhenTapOnBlurArea: true)
        view.modalTransitioningFactory = transitionFactory

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
