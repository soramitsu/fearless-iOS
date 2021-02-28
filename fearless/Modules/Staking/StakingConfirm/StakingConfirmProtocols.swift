protocol StakingConfirmViewProtocol: class {}

protocol StakingConfirmPresenterProtocol: class {
    func setup()
}

protocol StakingConfirmInteractorInputProtocol: class {}

protocol StakingConfirmInteractorOutputProtocol: class {}

protocol StakingConfirmWireframeProtocol: class {}

protocol StakingConfirmViewFactoryProtocol: class {
	static func createView() -> StakingConfirmViewProtocol?
}
