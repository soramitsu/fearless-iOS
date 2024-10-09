import Foundation
import SoraFoundation
import SSFModels

protocol StakingRewardDestSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveRewardDestination(viewModel: ChangeRewardDestinationViewModel?)
}

protocol StakingRewardDestSetupPresenterProtocol: AnyObject {
    func setup()
    func selectRestakeDestination()
    func selectPayoutDestination()
    func selectPayoutAccount()
    func displayLearnMore()
    func proceed()
}

protocol StakingRewardDestSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(rewardDestination: RewardDestination<AccountAddress>)
    func fetchPayoutAccounts()
}

protocol StakingRewardDestSetupInteractorOutputProtocol: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveController(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStash(result: Result<ChainAccountResponse?, Error>)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveRewardDestinationAccount(result: Result<RewardDestination<ChainAccountResponse>?, Error>)
    func didReceiveRewardDestinationAddress(result: Result<RewardDestination<AccountAddress>?, Error>)
    func didReceiveCalculator(result: Result<RewardCalculatorEngineProtocol?, Error>)
    func didReceiveAccounts(result: Result<[ChainAccountResponse], Error>)
    func didReceiveNomination(result: Result<Nomination?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
}

protocol StakingRewardDestSetupWireframeProtocol: WebPresentable, SheetAlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AccountSelectionPresentable {
    func proceed(
        view: StakingRewardDestSetupViewProtocol?,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        asset: AssetModel,
        chain: ChainModel,
        selectedAccount: MetaAccountModel
    )
}
