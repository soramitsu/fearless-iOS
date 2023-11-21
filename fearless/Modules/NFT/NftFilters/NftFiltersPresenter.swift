import Foundation
import SoraFoundation

final class NftFiltersPresenter {
    weak var view: NftFiltersViewProtocol?
    let router: NftFiltersRouterProtocol
    let interactor: NftFiltersInteractorInputProtocol
    let viewModelFactory: FiltersViewModelFactoryProtocol
    weak var moduleOutput: NftFiltersModuleOutput?

    init(
        interactor: NftFiltersInteractorInputProtocol,
        router: NftFiltersRouterProtocol,
        viewModelFactory: FiltersViewModelFactoryProtocol,
        moduleOutput: NftFiltersModuleOutput?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.router = router
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
        self.localizationManager = localizationManager
    }
}

extension NftFiltersPresenter: NftFiltersPresenterProtocol {
    func setup() {
        interactor.setup()

        view?.didReceive(locale: selectedLocale)
    }

    func didTapCloseButton() {
        router.close(view: view)
    }

    func willDisappear() {
        interactor.applyFilters()
    }
}

extension NftFiltersPresenter: NftFiltersInteractorOutputProtocol {
    func didReceive(filters: [FilterSet]) {
        let viewModel = viewModelFactory.buildViewModel(from: filters, delegate: self)
        view?.didReceive(state: .loaded(viewModel: viewModel))
    }

    func didFinishWithFilters(filters: [FilterSet]) {
        moduleOutput?.didFinishWithFilters(filters: filters)
    }
}

extension NftFiltersPresenter: SwitchFilterTableCellViewModelDelegate {
    func filterStateChanged(filterId: String, selected: Bool) {
        interactor.switchFilterState(id: filterId, selected: selected) { _ in }
    }
}

extension NftFiltersPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}
