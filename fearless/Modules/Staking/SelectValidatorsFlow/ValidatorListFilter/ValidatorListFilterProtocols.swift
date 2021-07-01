import SoraFoundation

protocol ValidatorListFilterWireframeProtocol {
    func close(_ view: ControllerBackedProtocol?)
}

protocol ValidatorListFilterViewProtocol: ControllerBackedProtocol, Localizable {
    func didUpdateViewModel(_ viewModel: ValidatorListFilterViewModel)
}

protocol ValidatorListFilterPresenterProtocol: Localizable {
    var view: ValidatorListFilterViewProtocol? { get set }

    func setup()

    func toggleFilterItem(at index: Int)
    func selectFilterItem(at index: Int)
    func applyFilter()
    func resetFilter()
}

protocol ValidatorListFilterViewFactoryProtocol {
    static func createView(
        with filter: CustomValidatorListFilter,
        delegate: ValidatorListFilterDelegate?
    ) -> ValidatorListFilterViewProtocol?
}

protocol ValidatorListFilterDelegate: AnyObject {
    func didUpdate(_ filter: CustomValidatorListFilter)
}
