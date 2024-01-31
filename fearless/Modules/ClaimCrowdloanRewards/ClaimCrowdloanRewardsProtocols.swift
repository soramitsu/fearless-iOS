import SSFModels
import SoraFoundation

typealias ClaimCrowdloanRewardsModuleCreationResult = (view: ClaimCrowdloanRewardsViewInput, input: ClaimCrowdloanRewardsModuleInput)

protocol ClaimCrowdloanRewardsViewInput: ControllerBackedProtocol {
    func didReceiveFeeViewModel(_ feeViewModel: BalanceViewModelProtocol?)
    func didReceiveVestingViewModel(_ viewModel: BalanceViewModelProtocol?)
    func didReceiveBalanceViewModel(_ viewModel: BalanceViewModelProtocol?)
    func didReceiveStakeAmountViewModel(_ stakeAmountViewModel: LocalizableResource<StakeAmountViewModel>)
    func didReceiveHintViewModel(_ hintViewModel: DetailsTriangularedAttributedViewModel?)
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
    func didReceiveFee(_ fee: RuntimeDispatchInfo)
    func didReceiveFeeError(_ error: Error)
    func didReceiveTxHash(_ txHash: String)
    func didReceiveTxError(_ error: Error)
    func didReceivePrice(_ price: PriceData?)
    func didReceivePriceError(_ error: Error)
    func didReceiveAccountInfo(accountInfo: AccountInfo?)
}

protocol ClaimCrowdloanRewardsRouterInput: AnyObject, AllDonePresentable, SheetAlertPresentable, ErrorPresentable, AnyDismissable {}

protocol ClaimCrowdloanRewardsModuleInput: AnyObject {}

protocol ClaimCrowdloanRewardsModuleOutput: AnyObject {}
