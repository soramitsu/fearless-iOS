import SoraFoundation

protocol CustomValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]?)
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
    func fillWithRecommended()
}

protocol CustomValidatorListViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        from validators: [ElectedValidatorInfo],
        selectedValidators: Set<ElectedValidatorInfo>,
        totalValidatorsCount: Int,
        filter: CustomValidatorListFilter,
        locale: Locale
    ) -> CustomValidatorListViewModel
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
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        reload(viewModel, at: indexes)
    }
}
