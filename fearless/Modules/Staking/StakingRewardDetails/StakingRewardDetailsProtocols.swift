import SoraFoundation

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingRewardDetailsPresenterProtocol: AnyObject {
    func setup()
    func handlePayoutAction()
}

protocol StakingRewardDetailsInteractorInputProtocol: AnyObject {}

protocol StakingRewardDetailsInteractorOutputProtocol: AnyObject {}

protocol StakingRewardDetailsWireframeProtocol: AnyObject {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?)
}

protocol StakingRewardDetailsViewFactoryProtocol: AnyObject {
    static func createView() -> StakingRewardDetailsViewProtocol?
}
