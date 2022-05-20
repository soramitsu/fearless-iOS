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

protocol CustomValidatorListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CustomValidatorListInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol CustomValidatorListWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func present(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: ValidatorInfoFlow,
        from view: ControllerBackedProtocol?
    )

    func presentFilters(
        from view: ControllerBackedProtocol?,
        flow: ValidatorListFilterFlow,
        delegate: ValidatorListFilterDelegate?,
        asset: AssetModel
    )

    func presentSearch(
        from view: ControllerBackedProtocol?,
        flow: ValidatorSearchFlow,
        delegate: ValidatorSearchDelegate?,
        chainAsset: ChainAsset
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
