import SoraFoundation
import SSFModels

protocol CustomValidatorListViewProtocol: ControllerBackedProtocol, Localizable {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]?)
    func setFilterAppliedState(to state: Bool)
}

protocol CustomValidatorListPresenterProtocol: SelectedValidatorListDelegate {
    func setup()

    func fillWithRecommended()
    func clearFilter()
    func deselectAll()
    func changeValidatorSelection(address: String)
    func didSelectValidator(address: String)
    func presentFilter()
    func presentSearch()
    func changeIdentityFilterValue()
    func changeMinBondFilterValue()
    func proceed()
    func searchTextDidChange(_ text: String?)
}

protocol CustomValidatorListInteractorInputProtocol: AnyObject {
    func setup()
}

protocol CustomValidatorListInteractorOutputProtocol: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol CustomValidatorListWireframeProtocol: SheetAlertPresentable, ErrorPresentable, StakingErrorPresentable {
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
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func proceed(
        from view: ControllerBackedProtocol?,
        flow: SelectedValidatorListFlow,
        delegate: SelectedValidatorListDelegate,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )

    func confirm(
        from view: ControllerBackedProtocol?,
        flow: SelectValidatorsConfirmFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    )
}

extension CustomValidatorListViewProtocol {
    func reload(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]? = nil) {
        reload(viewModel, at: indexes)
    }
}
