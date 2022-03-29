import Foundation
@testable import fearless
import RobinHood
import FearlessUtils

final class CrowdloansOperationFactoryStub: CrowdloanOperationFactoryProtocol {
    let crowdloans: [Crowdloan]
    let parachainLeaseInfo: [ParachainLeaseInfo]

    init(crowdloans: [Crowdloan], parachainLeaseInfo: [ParachainLeaseInfo]) {
        self.crowdloans = crowdloans
        self.parachainLeaseInfo = parachainLeaseInfo
    }

    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<[Crowdloan]> {
        CompoundOperationWrapper.createWithResult(crowdloans)
    }

    func fetchContributionOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        accountId: AccountId,
        fundIndex: FundIndex
    ) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        CompoundOperationWrapper.createWithResult(
            CrowdloanContributionResponse(accountId: accountId, fundIndex: fundIndex, contribution: nil)
        )
    }

    func fetchLeaseInfoOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        paraIds: [ParaId]
    ) -> CompoundOperationWrapper<[ParachainLeaseInfo]> {
        CompoundOperationWrapper.createWithResult(parachainLeaseInfo)
    }
}
