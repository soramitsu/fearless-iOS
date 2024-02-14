import Foundation

protocol NftFiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(state: FiltersViewState)
    func didReceive(locale: Locale)
}

protocol NftFiltersPresenterProtocol: AnyObject {
    func setup()
    func didTapCloseButton()
    func willDisappear()
}

protocol NftFiltersInteractorInputProtocol: AnyObject {
    func setup()
    func applyFilters()
    func switchFilterState(id: String, selected: Bool, completion: (Bool) -> Void)
}

protocol NftFiltersInteractorOutputProtocol: AnyObject {
    func didReceive(filters: [FilterSet])
    func didFinishWithFilters(filters: [FilterSet])
}

protocol NftFiltersRouterProtocol: AnyObject {
    func close(view: ControllerBackedProtocol?)
}

protocol NftFiltersModuleOutput: AnyObject {
    func didFinishWithFilters(filters: [FilterSet])
}
