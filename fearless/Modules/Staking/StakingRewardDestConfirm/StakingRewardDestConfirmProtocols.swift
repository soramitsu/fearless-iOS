import SoraFoundation
import SSFModels

protocol StakingRewardDestConfirmViewProtocol: ControllerBackedProtocol, Localizable, LoadableViewProtocol {
    func didReceiveConfirmation(viewModel: StakingRewardDestConfirmViewModel)
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
}

protocol StakingRewardDestConfirmPresenterProtocol: AnyObject {
    func setup()
    func confirm()
    func presentSenderAccountOptions()
    func presentPayoutAccountOptions()
}

protocol StakingRewardDestConfirmInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for rewardDestination: RewardDestination<AccountAddress>, stashItem: StashItem)
    func submit(rewardDestination: RewardDestination<AccountAddress>, for stashItem: StashItem)
}

protocol StakingRewardDestConfirmInteractorOutputProtocol: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didSubmitRewardDest(result: Result<String, Error>)
}

protocol StakingRewardDestConfirmWireframeProtocol: SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func complete(from view: StakingRewardDestConfirmViewProtocol?)
}
