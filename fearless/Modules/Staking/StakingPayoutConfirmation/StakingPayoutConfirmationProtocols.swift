import SoraFoundation

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingPayoutConfirmationPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingPayoutConfirmationInteractorInputProtocol: AnyObject {}

protocol StakingPayoutConfirmationInteractorOutputProtocol: AnyObject {}

protocol StakingPayoutConfirmationWireframeProtocol: AnyObject {}

protocol StakingPayoutConfirmationViewFactoryProtocol: AnyObject {
    static func createView() -> StakingPayoutConfirmationViewProtocol?
}
