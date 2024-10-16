import SoraFoundation
import SSFModels

typealias BalanceLocksDetailModuleCreationResult = (view: BalanceLocksDetailViewInput, input: BalanceLocksDetailModuleInput)

protocol BalanceLocksDetailViewInput: ControllerBackedProtocol {
    func didReceiveStakingLocksViewModel(_ viewModel: BalanceLocksDetailStakingViewModel?) async
    func didReceivePoolLocksViewModel(_ viewModel: BalanceLocksDetailPoolViewModel?) async
    func didReceiveLiquidityPoolLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async
    func didReceiveGovernanceLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async
    func didReceiveCrowdloanLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async
    func didReceiveTotalLocksViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async
    func didReceiveAssetFrozenViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async
    func didReceiveAssetBlockedViewModel(_ viewModel: LocalizableResource<BalanceViewModelProtocol>?) async
}

protocol BalanceLocksDetailViewOutput: AnyObject {
    func didLoad(view: BalanceLocksDetailViewInput)
    func didTapCloseButton()
}

protocol BalanceLocksDetailInteractorInput: AnyObject {
    func setup(with output: BalanceLocksDetailInteractorOutput)
}

protocol BalanceLocksDetailInteractorOutput: AnyObject {
    func didReceiveStakingLocks(_ stakingLocks: StakingLocks?) async
    func didReceiveNominationPoolLocks(_ nominationPoolLocks: StakingLocks?) async
    func didReceiveGovernanceLocks(_ balanceLocks: Decimal?) async
    func didReceiveCrowdloanLocks(_ crowdloanLocks: Decimal?) async
    func didReceiveVestingLocks(_ vestingLocks: Decimal?) async
    func didReceiveAssetFrozen(_ frozen: Decimal?) async
    func didReceiveAssetBlocked(_ blocked: Decimal?) async

    func didReceiveStakingLocksError(_ error: Error) async
    func didReceiveNominationPoolLocksError(_ error: Error) async
    func didReceiveGovernanceLocksError(_ error: Error) async
    func didReceiveCrowdloanLocksError(_ error: Error) async
    func didReceiveVestingLocksError(_ error: Error) async
    func didReceiveAssetFrozenError(_ error: Error) async
    func didReceiveAssetBlockedError(_ error: Error) async
}

protocol BalanceLocksDetailRouterInput: AnyObject, AnyDismissable {}

protocol BalanceLocksDetailModuleInput: AnyObject {}

protocol BalanceLocksDetailModuleOutput: AnyObject {}
