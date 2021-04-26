import SoraFoundation

protocol StakingBalanceViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func reload(with viewModel: LocalizableResource<StakingBalanceViewModel>)
}

protocol StakingBalancePresenterProtocol: AnyObject {
    func setup()
    func handleBondMoreAction()
    func handleUnbondAction()
    func handleRedeemAction()
}

protocol StakingBalanceInteractorInputProtocol: AnyObject {
    func setup()
}

protocol StakingBalanceInteractorOutputProtocol: AnyObject {
    func didReceive(ledgerResult: Result<DyStakingLedger?, Error>)
    func didReceive(activeEraResult: Result<EraIndex?, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    func didReceive(electionStatusResult: Result<ElectionStatus?, Error>)
}

protocol StakingBalanceWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showBondMore(from view: ControllerBackedProtocol?)
    func showUnbond(from view: ControllerBackedProtocol?)
    func showRedeem(from view: ControllerBackedProtocol?)
    // func cancel() когда stashItem == nil
}
