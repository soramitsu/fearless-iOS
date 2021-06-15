import SoraFoundation

protocol CustomValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(_ viewModel: [CustomValidatorCellViewModel], at indexes: [Int]?)
    func setFilterAppliedState(to state: Bool)
}

protocol CustomValidatorListPresenterProtocol: AnyObject {
    func setup()
    func presentFilter()
    func presentSearch()
    func changeValidatorSelection(at index: Int)
    func didSelectValidator(at index: Int)
    func clearFilter()
    func deselectAll()
}

protocol CustomValidatorListViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        validators: [ElectedValidatorInfo],
        selectedValidators: Set<ElectedValidatorInfo>
    ) -> [CustomValidatorCellViewModel]
}

protocol CustomValidatorListInteractorInputProtocol: AnyObject {}

protocol CustomValidatorListInteractorOutputProtocol: AnyObject {}

protocol CustomValidatorListWireframeProtocol: AnyObject {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )
    func presentFilters()
    func presentSearch()
}

extension CustomValidatorListViewProtocol {
    func reload(_ viewModel: [CustomValidatorCellViewModel], at indexes: [Int]? = nil) {
        reload(viewModel, at: indexes)
    }
}
