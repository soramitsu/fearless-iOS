import SoraFoundation

protocol CustomValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]?)
    func setFilterAppliedState(to state: Bool)
}

protocol CustomValidatorListPresenterProtocol: SelectedValidatorListDelegate {
    func setup()

    func fillWithRecommended()
    func clearFilter()
    func deselectAll()

    func changeValidatorSelection(at index: Int)

    func didSelectValidator(at index: Int)
    func presentFilter()
    func presentSearch()
    func proceed()
}

protocol CustomValidatorListViewModelFactoryProtocol: AnyObject {
    func createViewModel(
        from validators: [ElectedValidatorInfo],
        selectedValidators: [ElectedValidatorInfo],
        totalValidatorsCount: Int,
        filter: CustomValidatorListFilter,
        priceData: PriceData?,
        locale: Locale
    ) -> CustomValidatorListViewModel
}

protocol CustomValidatorListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CustomValidatorListInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol CustomValidatorListWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func present(
        _ validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?
    )

    func presentFilters()
    func presentSearch()

    func proceed(
        from view: CustomValidatorListViewProtocol?,
        validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate
    )
}

extension CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        reload(viewModel, at: indexes)
    }
}
