import SoraFoundation

protocol StakingPayoutConfirmationViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingPayoutConfirmationPresenterProtocol: class {
    func setup()
}

protocol StakingPayoutConfirmationInteractorInputProtocol: class {}

protocol StakingPayoutConfirmationInteractorOutputProtocol: class {}

protocol StakingPayoutConfirmationWireframeProtocol: class {}

protocol StakingPayoutConfirmationViewFactoryProtocol: class {
	static func createView() -> StakingPayoutConfirmationViewProtocol?
}
