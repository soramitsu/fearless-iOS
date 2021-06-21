import Foundation
@testable import fearless
import RobinHood

final class CrowdloansOperationFactoryStub: CrowdloanOperationFactoryProtocol {
    let crowdloans: [Crowdloan]

    init(crowdloans: [Crowdloan]) {
        self.crowdloans = crowdloans
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
}
