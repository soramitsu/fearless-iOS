import Foundation
import SoraFoundation
import SoraUI

struct NftFiltersAssembly {
    static func configureModule(
        filters: [FilterSet],
        moduleOutput: NftFiltersModuleOutput?
    ) -> NftFiltersViewProtocol? {
        let interactor = NftFiltersInteractor(filters: filters)
        let router = NftFiltersRouter()

        let viewModelFactory: FiltersViewModelFactoryProtocol = NftFiltersViewModelFactory()
        let presenter = NftFiltersPresenter(
            interactor: interactor,
            router: router,
            viewModelFactory: viewModelFactory,
            moduleOutput: moduleOutput,
            localizationManager: LocalizationManager.shared
        )

        let view = NftFiltersViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return view
    }
}
