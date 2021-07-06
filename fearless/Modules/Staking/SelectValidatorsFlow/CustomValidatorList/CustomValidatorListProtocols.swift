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
        from validatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
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

    func presentFilters(
        from view: ControllerBackedProtocol?,
        filter: CustomValidatorListFilter,
        delegate: ValidatorListFilterDelegate?
    )

    func presentSearch(
        from view: ControllerBackedProtocol?,
        fullValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?
    )

    func proceed(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate
    )
}

protocol CustomValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol?

    static func createChangeTargetsView(
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol?

    static func createChangeYourValidatorsView(
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol?
}

extension CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        reload(viewModel, at: indexes)
    }
}
