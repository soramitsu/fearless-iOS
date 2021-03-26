import SoraFoundation

protocol StakingRewardDetailsViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingRewardDetailsPresenterProtocol: class {
    func setup()
}

protocol StakingRewardDetailsInteractorInputProtocol: class {}

protocol StakingRewardDetailsInteractorOutputProtocol: class {}

protocol StakingRewardDetailsWireframeProtocol: class {}

protocol StakingRewardDetailsViewFactoryProtocol: class {
	static func createView() -> StakingRewardDetailsViewProtocol?
}
