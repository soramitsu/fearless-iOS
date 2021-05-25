import Foundation
import CommonWallet

protocol CrowdloanContributionSetupViewProtocol: ControllerBackedProtocol {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveCrowdloan(viewModel: CrowdloanContributionViewModel)
}

protocol CrowdloanContributionSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
}

protocol CrowdloanContributionSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: Decimal)
}

protocol CrowdloanContributionSetupInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloan(result: Result<Crowdloan, Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfo?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}

protocol CrowdloanContributionSetupWireframeProtocol: AnyObject {}
