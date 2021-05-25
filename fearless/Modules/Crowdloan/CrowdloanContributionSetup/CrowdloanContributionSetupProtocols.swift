import Foundation

protocol CrowdloanContributionSetupViewProtocol: ControllerBackedProtocol {}

protocol CrowdloanContributionSetupPresenterProtocol: AnyObject {
    func setup()
}

protocol CrowdloanContributionSetupInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: Decimal)
}

protocol CrowdloanContributionSetupInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloans(result: Result<Crowdloan, Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfo?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}

protocol CrowdloanContributionSetupWireframeProtocol: AnyObject {}
