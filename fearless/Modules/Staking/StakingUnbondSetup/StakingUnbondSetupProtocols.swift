protocol StakingUnbondSetupViewProtocol: ControllerBackedProtocol {}

protocol StakingUnbondSetupPresenterProtocol: AnyObject {
    func setup()
}

protocol StakingUnbondSetupInteractorInputProtocol: AnyObject {}

protocol StakingUnbondSetupInteractorOutputProtocol: AnyObject {}

protocol StakingUnbondSetupWireframeProtocol: AnyObject {}

protocol StakingUnbondSetupViewFactoryProtocol: AnyObject {
    static func createView() -> StakingUnbondSetupViewProtocol?
}
