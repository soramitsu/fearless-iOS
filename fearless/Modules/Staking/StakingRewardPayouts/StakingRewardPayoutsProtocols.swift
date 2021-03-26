import SoraFoundation

protocol StakingRewardPayoutsViewProtocol: ControllerBackedProtocol, Localizable {}

protocol StakingRewardPayoutsPresenterProtocol: class {
    func setup()
    func handleSelectedHistory(at indexPath: IndexPath)
}

protocol StakingRewardPayoutsInteractorInputProtocol: class {}

protocol StakingRewardPayoutsInteractorOutputProtocol: class {}

protocol StakingRewardPayoutsWireframeProtocol: class {

    func showRewardDetails(from view: ControllerBackedProtocol?)
}

protocol StakingRewardPayoutsViewFactoryProtocol: class {
	static func createView() -> StakingRewardPayoutsViewProtocol?
}
