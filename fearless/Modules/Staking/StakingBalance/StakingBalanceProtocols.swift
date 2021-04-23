import SoraFoundation

protocol StakingBalanceViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {}

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
    func didReceive(balanceResult: Result<StakingBalanceData, Error>)
    func didReceive(priceResult: Result<PriceData?, Error>)
    // func did ledger
    // active era
}

protocol StakingBalanceWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showBondMore(from view: ControllerBackedProtocol?)
    func showUnbond(from view: ControllerBackedProtocol?)
    func showRedeem(from view: ControllerBackedProtocol?)
    // func cancel() когда stashItem == nil
}
