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
    func didReceive(ledgerResult: Result<DyStakingLedger?, Error>)
    func didReceive(activeEraResult: Result<EraIndex?, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(electionStatusResult: Result<ElectionStatus?, Error>)
    func didReceive(stashItemResult: Result<StashItem?, Error>)
    func didReceive(fetchControllerResult: Result<(AccountItem?, AccountAddress?), Error>)
}

protocol StakingBalanceWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showBondMore(from view: ControllerBackedProtocol?)
    func showUnbond(from view: ControllerBackedProtocol?)
    func showRedeem(from view: ControllerBackedProtocol?)
    // TODO: add func cancel() when stashItem == nil
}
