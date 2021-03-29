import SoraFoundation

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingRewardDetailsPresenterProtocol: class {
    func setup()
    func handlePayoutAction()
}

protocol StakingRewardDetailsInteractorInputProtocol: class {}

protocol StakingRewardDetailsInteractorOutputProtocol: class {}

protocol StakingRewardDetailsWireframeProtocol: class {

    func showPayoutConfirmation(from view: ControllerBackedProtocol?)
}

protocol StakingRewardDetailsViewFactoryProtocol: class {
	static func createView() -> StakingRewardDetailsViewProtocol?
}
