protocol StakingRewardPayoutsViewProtocol: class {}

protocol StakingRewardPayoutsPresenterProtocol: class {
    func setup()
}

protocol StakingRewardPayoutsInteractorInputProtocol: class {}

protocol StakingRewardPayoutsInteractorOutputProtocol: class {}

protocol StakingRewardPayoutsWireframeProtocol: class {}

protocol StakingRewardPayoutsViewFactoryProtocol: class {
	static func createView() -> StakingRewardPayoutsViewProtocol?
}