typealias BalanceLocksDetailModuleCreationResult = (view: BalanceLocksDetailViewInput, input: BalanceLocksDetailModuleInput)

protocol BalanceLocksDetailViewInput: ControllerBackedProtocol {}

protocol BalanceLocksDetailViewOutput: AnyObject {
    func didLoad(view: BalanceLocksDetailViewInput)
}

protocol BalanceLocksDetailInteractorInput: AnyObject {
    func setup(with output: BalanceLocksDetailInteractorOutput)
}

protocol BalanceLocksDetailInteractorOutput: AnyObject {
    func didReceiveStakingLedger(_ stakingLedger: StakingLedger?)
    func didReceiveStakingPoolMember(_ stakingPoolMember: StakingPoolMember?)
    func didReceiveBalanceLocks(_ balanceLocks: BalanceLocks?)
    func didReceiveCrowdloanContributions(_ contributions: CrowdloanContributionDict?)
    
    func didReceiveStakingLedgerError(_ error: Error)
    func didReceiveStakingPoolError(_ error: Error)
    func didReceiveBalanceLocksError(_ error: Error)
    func didReceiveCrowdloanContributionsError(_ error: Error)
}

protocol BalanceLocksDetailRouterInput: AnyObject {}

protocol BalanceLocksDetailModuleInput: AnyObject {}

protocol BalanceLocksDetailModuleOutput: AnyObject {}
