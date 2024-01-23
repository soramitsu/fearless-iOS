typealias ClaimCrowdloanRewardsModuleCreationResult = (view: ClaimCrowdloanRewardsViewInput, input: ClaimCrowdloanRewardsModuleInput)

protocol ClaimCrowdloanRewardsViewInput: ControllerBackedProtocol {}

protocol ClaimCrowdloanRewardsViewOutput: AnyObject {
    func didLoad(view: ClaimCrowdloanRewardsViewInput)
}

protocol ClaimCrowdloanRewardsInteractorInput: AnyObject {
    func setup(with output: ClaimCrowdloanRewardsInteractorOutput)
}

protocol ClaimCrowdloanRewardsInteractorOutput: AnyObject {
    func didReceiveBalanceLocks(_ balanceLocks: BalanceLocks?)
    func didReceiveBalanceLocksError(_ error: Error)
}

protocol ClaimCrowdloanRewardsRouterInput: AnyObject {}

protocol ClaimCrowdloanRewardsModuleInput: AnyObject {}

protocol ClaimCrowdloanRewardsModuleOutput: AnyObject {}
