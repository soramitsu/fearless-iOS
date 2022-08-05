typealias StakingPoolMainModuleCreationResult = (view: StakingPoolMainViewInput, input: StakingPoolMainModuleInput)

protocol StakingPoolMainViewInput: ControllerBackedProtocol {}

protocol StakingPoolMainViewOutput: AnyObject {
    func didLoad(view: StakingPoolMainViewInput)
}

protocol StakingPoolMainInteractorInput: AnyObject {
    func setup(with output: StakingPoolMainInteractorOutput)
}

protocol StakingPoolMainInteractorOutput: AnyObject {}

protocol StakingPoolMainRouterInput: AnyObject {}

protocol StakingPoolMainModuleInput: AnyObject {}

protocol StakingPoolMainModuleOutput: AnyObject {}
