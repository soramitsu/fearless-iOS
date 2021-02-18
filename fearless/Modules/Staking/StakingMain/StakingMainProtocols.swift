import Foundation

protocol StakingMainViewProtocol: ControllerBackedProtocol {
    func didReceive(viewModel: StakingMainViewModelProtocol)
}

protocol StakingMainPresenterProtocol: class {
    func setup()
    func performMainAction()
    func performAccountAction()
}

protocol StakingMainInteractorInputProtocol: class {
    func setup()
}

protocol StakingMainInteractorOutputProtocol: class {
    func didReceive(selectedAddress: String)
}

protocol StakingMainWireframeProtocol: class {
    func showStartStaking()
}

protocol StakingMainViewFactoryProtocol: class {
	static func createView() -> StakingMainViewProtocol?
}
