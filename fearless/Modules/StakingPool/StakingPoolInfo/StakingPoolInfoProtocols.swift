typealias StakingPoolInfoModuleCreationResult = (view: StakingPoolInfoViewInput, input: StakingPoolInfoModuleInput)

protocol StakingPoolInfoViewInput: ControllerBackedProtocol {
    func didReceive(viewModel: StakingPoolInfoViewModel)
}

protocol StakingPoolInfoViewOutput: AnyObject {
    func didLoad(view: StakingPoolInfoViewInput)
    func didTapCloseButton()
}

protocol StakingPoolInfoInteractorInput: AnyObject {
    func setup(with output: StakingPoolInfoInteractorOutput)
}

protocol StakingPoolInfoInteractorOutput: AnyObject {
    func didReceivePriceData(result: Result<PriceData?, Error>)
}

protocol StakingPoolInfoRouterInput: AnyObject, PresentDismissable {}

protocol StakingPoolInfoModuleInput: AnyObject {}

protocol StakingPoolInfoModuleOutput: AnyObject {}
