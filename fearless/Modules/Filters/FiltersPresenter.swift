import Foundation

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
        moduleOutput: FiltersModuleOutput?
    ) {
        self.interactor = interactor
        self.wireframe = wireframe
        self.viewModelFactory = viewModelFactory
        self.moduleOutput = moduleOutput
    }
}

extension FiltersPresenter: FiltersPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func didTapApplyButton() {
        interactor.applyFilters()
        wireframe.close(view: view)
    }

    func didTapResetButton() {
        interactor.resetFilters()
    }
}

extension FiltersPresenter: FiltersInteractorOutputProtocol {
    func didReceive(filterItems: [BaseFilterItem]) {
        let viewModel = viewModelFactory.buildViewModel(from: filterItems)
        view?.didReceive(state: .loaded(viewModel: viewModel))
    }

    func didFinishWithFilters(filters: [BaseFilterItem]) {
        moduleOutput?.didFinishWithFilters(filters: filters)
    }
}
