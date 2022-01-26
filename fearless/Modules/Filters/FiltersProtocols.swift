protocol FiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(state: FiltersViewState)
}

protocol FiltersPresenterProtocol: AnyObject {
    func setup()
    func didTapResetButton()
    func didTapApplyButton()
}

protocol FiltersInteractorInputProtocol: AnyObject {
    func setup()
    func resetFilters()
    func applyFilters()
}

protocol FiltersInteractorOutputProtocol: AnyObject {
    func didReceive(filterItems: [BaseFilterItem])
    func didFinishWithFilters(filters: [BaseFilterItem])
}

protocol FiltersWireframeProtocol: AnyObject {
    func close(view: ControllerBackedProtocol?)
}

protocol FiltersModuleOutput: AnyObject {
    func didFinishWithFilters(filters: [BaseFilterItem])
}
