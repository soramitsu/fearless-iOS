import Foundation

protocol FiltersViewProtocol: ControllerBackedProtocol {
    func didReceive(state: FiltersViewState)
    func didReceive(locale: Locale)
}

protocol FiltersPresenterProtocol: AnyObject {
    func setup()
    func didTapResetButton()
    func didTapApplyButton()
    func didTapCloseButton()
}

protocol FiltersInteractorInputProtocol: AnyObject {
    func setup()
    func resetFilters()
    func applyFilters()
    func switchFilterState(id: String, selected: Bool)
}

protocol FiltersInteractorOutputProtocol: AnyObject {
    func didReceive(filters: [FilterSet])
    func didFinishWithFilters(filters: [FilterSet])
}

protocol FiltersWireframeProtocol: AnyObject {
    func close(view: ControllerBackedProtocol?)
}

protocol FiltersModuleOutput: AnyObject {
    func didFinishWithFilters(filters: [FilterSet])
}
