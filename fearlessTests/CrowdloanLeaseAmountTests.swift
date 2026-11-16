import XCTest
import BigInt
import RobinHood
import SSFUtils
@testable import fearless

/// fetchLeaseInfoOperation meant to report a parachain fund's largest lease, but passed `>` to `max(by:)`, whose
/// closure asks "is the first smaller", so it reported the smallest. No screen calls it today.
final class CrowdloanLeaseAmountTests: XCTestCase {
    func testTheLargestLeaseOfTheFundIsReported() throws {
        let storage = CovJFinStorageRequestFactory()
        let fund = CovJFinCrowdloanFixture.fundAccount(2000)
        storage.responses = [
            StorageResponse<[ParachainSlotLease?]>(
                key: Data([1]), data: nil,
                value: try CovJFinCrowdloanFixture.leases([(fund, 500), nil, (fund, 800), (Data(repeating: 9, count: 32), 900)])
            )
        ]
        let factory = CrowdloanOperationFactory(
            requestOperationFactory: storage,
            operationManager: OperationManager(operationQueue: OperationQueue()),
            chainRegistry: CovJFinChainRegistry()
        )

        let infos = try CovJFinCrowdloanFixture.run(factory.fetchLeaseInfoOperation(
            connection: CovJFinEngine(),
            runtimeService: try CovJFinCrowdloanFixture.emptyRuntime(),
            paraIds: [2000]
        ))

        XCTAssertEqual(infos.map(\.leasedAmount), [BigUInt(800)])
    }
}
