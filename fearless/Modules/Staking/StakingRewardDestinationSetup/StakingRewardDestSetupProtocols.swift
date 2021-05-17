import Foundation
import SoraFoundation

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
    func estimateFee()
    func fetchPayoutAccounts()
}

protocol StakingRewardDestSetupInteractorOutputProtocol: AnyObject {
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveStash(result: Result<AccountItem?, Error>)
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>)
    func didReceiveRewardDestinationAccount(result: Result<RewardDestination<AccountItem>?, Error>)
    func didReceiveRewardDestinationAddress(result: Result<RewardDestination<AccountAddress>?, Error>)
    func didReceiveCalculator(result: Result<RewardCalculatorEngineProtocol?, Error>)
    func didReceiveAccounts(result: Result<[AccountItem], Error>)
    func didReceiveElectionStatus(result: Result<ElectionStatus?, Error>)
    func didReceiveNomination(result: Result<Nomination?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
}

protocol StakingRewardDestSetupWireframeProtocol: WebPresentable, AlertPresentable, ErrorPresentable,
    StakingErrorPresentable, AccountSelectionPresentable {
    func proceed(view: StakingRewardDestSetupViewProtocol?, rewardDestination: RewardDestination<AccountItem>)
}

protocol StakingRewardDestSetupViewFactoryProtocol {
    static func createView() -> StakingRewardDestSetupViewProtocol?
}
