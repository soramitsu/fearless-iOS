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
        asset: AssetModel,
        chain: ChainModel,
        validatorInfo: ValidatorInfoProtocol,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    )

    func presentFilters(
        from view: ControllerBackedProtocol?,
        filter: CustomValidatorListFilter,
        delegate: ValidatorListFilterDelegate?,
        asset: AssetModel
    )

    func presentSearch(
        from view: ControllerBackedProtocol?,
        fullValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchDelegate?,
        chain: ChainModel,
        asset: AssetModel,
        wallet: MetaAccountModel
    )

    func proceed(
        from view: ControllerBackedProtocol?,
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    )
}

extension CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        reload(viewModel, at: indexes)
    }
}
