import Foundation
import SoraFoundation

final class FiltersPresenter {
    weak var view: FiltersViewProtocol?
    let wireframe: FiltersWireframeProtocol
    let interactor: FiltersInteractorInputProtocol
    let viewModelFactory: FiltersViewModelFactoryProtocol
    weak var moduleOutput: FiltersModuleOutput?

    init(
        interactor: FiltersInteractorInputProtocol,
        wireframe: FiltersWireframeProtocol,
        viewModelFactory: FiltersViewModelFactoryProtocol,
        moduleOutput: FiltersModuleOutput?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
        self.localizationManager = localizationManager
    }
}

extension FiltersPresenter: FiltersPresenterProtocol {
    func setup() {
        interactor.setup()

        view?.didReceive(locale: selectedLocale)
    }

    func didTapApplyButton() {
        interactor.applyFilters()
        wireframe.close(view: view)
    }

    func didTapResetButton() {
        interactor.resetFilters()
    }

    func didTapCloseButton() {
        wireframe.close(view: view)
    }
}

extension FiltersPresenter: FiltersInteractorOutputProtocol {
    func didReceive(filters: [FilterSet]) {
        let viewModel = viewModelFactory.buildViewModel(from: filters, delegate: self)
        view?.didReceive(state: .loaded(viewModel: viewModel))
    }

    func didFinishWithFilters(filters: [FilterSet]) {
        moduleOutput?.didFinishWithFilters(filters: filters)
    }
}

extension FiltersPresenter: SwitchFilterTableCellViewModelDelegate {
    func filterStateChanged(filterId: String, selected: Bool) {
        interactor.switchFilterState(id: filterId, selected: selected) { validState in
            view?.didReceive(applyEnabled: validState)
        }
    }
}

extension FiltersPresenter: Localizable {
    func applyLocalization() {
        view?.didReceive(locale: selectedLocale)
    }
}
