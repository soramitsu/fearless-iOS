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
}
