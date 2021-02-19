import Foundation

protocol StakingAmountViewProtocol: ControllerBackedProtocol {}

protocol StakingAmountPresenterProtocol: class {
    func setup()
    func close()
}

protocol StakingAmountInteractorInputProtocol: class {}

protocol StakingAmountInteractorOutputProtocol: class {}

protocol StakingAmountWireframeProtocol: class {
    func close(view: StakingAmountViewProtocol?)
}

protocol StakingAmountViewFactoryProtocol: class {
	static func createView() -> StakingAmountViewProtocol?
}
