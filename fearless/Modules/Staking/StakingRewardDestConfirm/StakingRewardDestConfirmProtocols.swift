import SoraFoundation

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
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didSubmitRewardDest(result: Result<String, Error>)
}

protocol StakingRewardDestConfirmWireframeProtocol: AlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AddressOptionsPresentable {
    func complete(from view: StakingRewardDestConfirmViewProtocol?)
}
