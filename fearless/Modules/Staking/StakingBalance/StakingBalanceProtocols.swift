import SoraFoundation

protocol StakingBalanceViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>)
}

protocol StakingBalanceViewModelFactoryProtocol {
    func createViewModel(from balanceData: StakingBalanceData) -> LocalizableResource<StakingBalanceViewModel>
}

protocol StakingBalancePresenterProtocol: AnyObject {
    func setup()
    func handleAction(_ action: StakingBalanceAction)
    func handleUnbondingMoreAction()
}

protocol StakingBalanceInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingBalanceInteractorOutputProtocol: AnyObject {
    func didReceive(ledgerResult: Result<StakingLedger?, Error>)
    func didReceive(activeEraResult: Result<EraIndex?, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(electionStatusResult: Result<ElectionStatus?, Error>)
    func didReceive(stashItemResult: Result<StashItem?, Error>)
    func didReceive(controllerResult: Result<AccountItem?, Error>)
    func didReceive(stashResult: Result<AccountItem?, Error>)
}

protocol StakingBalanceWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showBondMore(from view: ControllerBackedProtocol?)
    func showUnbond(from view: ControllerBackedProtocol?)
    func showRedeem(from view: ControllerBackedProtocol?)
    func showRebond(from view: ControllerBackedProtocol?, option: StakingRebondOption)
    func cancel(from view: ControllerBackedProtocol?)
}
