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

protocol StakingBalanceInteractorOutputProtocol: AnyObject {}

protocol StakingBalanceWireframeProtocol: AlertPresentable, ErrorPresentable, StakingErrorPresentable {
    func showBondMore(from view: ControllerBackedProtocol?)
    func showUnbond(from view: ControllerBackedProtocol?)
    func showRedeem(from view: ControllerBackedProtocol?)
}

protocol StakingBalanceViewFactoryProtocol: AnyObject {
    static func createView() -> StakingBalanceViewProtocol?
}
