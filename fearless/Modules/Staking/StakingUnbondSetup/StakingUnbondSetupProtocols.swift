import Foundation

protocol StakingUnbondSetupViewProtocol: ControllerBackedProtocol {}

protocol StakingUnbondSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
    func close()
}

protocol StakingUnbondSetupInteractorInputProtocol: AnyObject {}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {}

protocol StakingUnbondSetupWireframeProtocol: AnyObject {
    func close(view: StakingUnbondSetupViewProtocol?)
}

protocol StakingUnbondSetupViewFactoryProtocol: AnyObject {
    static func createView() -> StakingUnbondSetupViewProtocol?
}
