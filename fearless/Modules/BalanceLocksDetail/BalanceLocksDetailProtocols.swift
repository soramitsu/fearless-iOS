import SoraFoundation
import SSFModels

typealias BalanceLocksDetailModuleCreationResult = (view: BalanceLocksDetailViewInput, input: BalanceLocksDetailModuleInput)

protocol BalanceLocksDetailViewInput: ControllerBackedProtocol {
    func didReceiveStakingLocksViewModel(_ viewModel: BalanceLocksDetailStakingViewModel?)
    func didReceivePoolLocksViewModel(_ viewModel: BalanceLocksDetailPoolViewModel?)
    func didReceiveLiquidityPoolLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveGovernanceLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveCrowdloanLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

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
    func didReceivePrice(_ price: PriceData?)
    func didReceiveVestingSchedule(_ vestingSchedule: VestingSchedule?)
    func didReceiveVestingVesting(_ vesting: VestingVesting?)

    func didReceiveStakingLedgerError(_ error: Error)
    func didReceiveStakingPoolError(_ error: Error)
    func didReceiveBalanceLocksError(_ error: Error)
    func didReceiveCrowdloanContributionsError(_ error: Error)
    func didReceivePriceError(_ error: Error)
    func didReceiveVestingScheduleError(_ error: Error)
    func didReceiveVestingVestingError(_ error: Error)
}

protocol BalanceLocksDetailRouterInput: AnyObject {}

protocol BalanceLocksDetailModuleInput: AnyObject {}

protocol BalanceLocksDetailModuleOutput: AnyObject {}
