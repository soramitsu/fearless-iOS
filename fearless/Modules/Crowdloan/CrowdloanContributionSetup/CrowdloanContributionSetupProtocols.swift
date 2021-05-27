import Foundation
import CommonWallet
import BigInt
import SoraFoundation

protocol CrowdloanContributionSetupViewProtocol: ControllerBackedProtocol, Localizable {
    func didReceiveAsset(viewModel: AssetBalanceViewModelProtocol)
    func didReceiveFee(viewModel: BalanceViewModelProtocol?)
    func didReceiveInput(viewModel: AmountInputViewModelProtocol)
    func didReceiveCrowdloan(viewModel: CrowdloanContributionViewModel)
    func didReceiveEstimatedReward(viewModel: String?)
}

protocol CrowdloanContributionSetupPresenterProtocol: AnyObject {
    func setup()
    func selectAmountPercentage(_ percentage: Float)
    func updateAmount(_ newValue: Decimal)
    func proceed()
}

protocol CrowdloanContributionSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: BigUInt)
}

protocol CrowdloanContributionSetupInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloan(result: Result<Crowdloan, Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfo?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}

protocol CrowdloanContributionSetupWireframeProtocol: AlertPresentable, ErrorPresentable,
    CrowdloanErrorPresentable {
    func showConfirmation(from view: CrowdloanContributionSetupViewProtocol?, inputAmount: Decimal)
}
