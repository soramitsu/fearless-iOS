import Foundation
@testable import fearless
import RobinHood

final class CrowdloansOperationFactoryStub: CrowdloanOperationFactoryProtocol {
    let crowdloans: [Crowdloan]
    let parachainLeaseInfo: [ParachainLeaseInfo]

    init(crowdloans: [Crowdloan], parachainLeaseInfo: [ParachainLeaseInfo]) {
        self.crowdloans = crowdloans
        self.parachainLeaseInfo = parachainLeaseInfo
    }

    func fetchCrowdloansOperation(
        connection: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        chain: Chain
    ) -> CompoundOperationWrapper<[Crowdloan]> {
        CompoundOperationWrapper.createWithResult(crowdloans)
    }

    func fetchContributionOperation(connection: JSONRPCEngine, runtimeService: RuntimeCodingServiceProtocol, address: AccountAddress, trieIndex: UInt32) -> CompoundOperationWrapper<CrowdloanContributionResponse> {
        CompoundOperationWrapper.createWithResult(
            CrowdloanContributionResponse(address: address, trieIndex: trieIndex, contribution: nil)
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
