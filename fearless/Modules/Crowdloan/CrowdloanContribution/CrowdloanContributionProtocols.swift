import Foundation
import BigInt

protocol CrowdloanContributionInteractorInputProtocol: AnyObject {
    func setup()
    func estimateFee(for amount: BigUInt)
}

protocol CrowdloanContributionInteractorOutputProtocol: AnyObject {
    func didReceiveCrowdloan(result: Result<Crowdloan, Error>)
    func didReceiveDisplayInfo(result: Result<CrowdloanDisplayInfo?, Error>)
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>)
    func didReceiveBlockNumber(result: Result<BlockNumber?, Error>)
    func didReceiveBlockDuration(result: Result<BlockTime, Error>)
    func didReceiveLeasingPeriod(result: Result<LeasingPeriod, Error>)
    func didReceiveMinimumBalance(result: Result<BigUInt, Error>)
    func didReceiveMinimumContribution(result: Result<BigUInt, Error>)
    func didReceivePriceData(result: Result<PriceData?, Error>)
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>)
}
