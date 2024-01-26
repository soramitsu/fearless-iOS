import SSFModels
import SoraFoundation

typealias ClaimCrowdloanRewardsModuleCreationResult = (view: ClaimCrowdloanRewardsViewInput, input: ClaimCrowdloanRewardsModuleInput)

protocol ClaimCrowdloanRewardsViewInput: ControllerBackedProtocol {
    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?)
    func didReceiveViewModel(_ viewModel: ClaimCrowdloanRewardsViewModel)
    func didReceiveStakeAmountViewModel(_ stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>)
    func didReceiveHintViewModel(_ hintViewModel: TitleIconViewModel?)
}

protocol ClaimCrowdloanRewardsViewOutput: AnyObject {
    func didLoad(view: ClaimCrowdloanRewardsViewInput)
    func backButtonClicked()
    func confirmButtonClicked()
}

protocol ClaimCrowdloanRewardsInteractorInput: AnyObject {
    func setup(with output: ClaimCrowdloanRewardsInteractorOutput)
    func estimateFee()
    func submit()
}

protocol ClaimCrowdloanRewardsInteractorOutput: AnyObject {
    func didReceiveBalanceLocks(_ balanceLocks: [LockProtocol]?)
    func didReceiveBalanceLocksError(_ error: Error)
    func didReceiveTokenLocks(_ balanceLocks: [LockProtocol]?)
    func didReceiveTokenLocksError(_ error: Error)
    func didReceiveVestingSchedule(_ vestingSchedule: VestingSchedule?)
    func didReceiveVestingScheduleError(_ error: Error)
    func didReceiveVestingVesting(_ vesting: VestingVesting?)
    func didReceiveVestingVestingError(_ error: Error)
    func didReceiveFee(_ fee: RuntimeDispatchInfo)
    func didReceiveFeeError(_ error: Error)
    func didReceiveTxHash(_ txHash: String)
    func didReceiveTxError(_ error: Error)
    func didReceivePrice(_ price: PriceData?)
    func didReceivePriceError(_ error: Error)
    func didReceiveCurrenBlock(_ currentBlock: UInt32?)
    func didReceiveCurrentBlockError(_ error: Error)
}

protocol ClaimCrowdloanRewardsRouterInput: AnyObject, AllDonePresentable, SheetAlertPresentable, ErrorPresentable, AnyDismissable {}

protocol ClaimCrowdloanRewardsModuleInput: AnyObject {}

protocol ClaimCrowdloanRewardsModuleOutput: AnyObject {}
