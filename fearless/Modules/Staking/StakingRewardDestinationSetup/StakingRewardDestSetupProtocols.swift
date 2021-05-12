import Foundation
import SoraFoundation

protocol StakingRewardDestSetupViewProtocol: ControllerBackedProtocol, Localizable {
    #warning("Not implemented")
    func didReceiveFee(viewModel: LocalizableResource<BalanceViewModelProtocol>?)
    func didReceiveRewardDestination(viewModel: LocalizableResource<RewardDestinationViewModelProtocol>)
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
}

protocol StakingRewardDestSetupInteractorOutputProtocol: AnyObject {
    #warning("Not implemented")
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveStashItem(result: Result<StashItem?, Error>)
    func didReceiveController(result: Result<AccountItem?, Error>)
    func didReceiveStakingLedger(result: Result<DyStakingLedger?, Error>)
    func didReceivePayee(result: Result<RewardDestinationArg?, Error>)
    func didReceiveCalculator(result: Result<RewardCalculatorEngineProtocol?, Error>)

//    func didReceiveAccountInfo(result: Result<DyAccountInfo?, Error>)
}

protocol StakingRewardDestSetupWireframeProtocol: WebPresentable, AlertPresentable, ErrorPresentable,
    StakingErrorPresentable {
    func proceed(view: StakingRewardDestSetupViewProtocol?)
}

protocol StakingRewardDestSetupViewFactoryProtocol {
    static func createView() -> StakingRewardDestSetupViewProtocol?
}
