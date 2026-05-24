import XCTest
@testable import fearless

final class StakingDurationOperationFactoryTests: XCTestCase {
    func testWestend_whenRuntimeConstantsAvailable_thenBuildsPositiveDurations() throws {
        let runtimeService = try RuntimeCodingServiceStub.createWestendService()
        let wrapper = StakingDurationOperationFactory().createDurationOperation(from: runtimeService)
        let queue = OperationQueue()

        queue.addOperations(wrapper.allOperations, waitUntilFinished: true)

        let duration = try wrapper.targetOperation.extractNoCancellableResultData()
        XCTAssertGreaterThan(duration.session, 0)
        XCTAssertGreaterThan(duration.era, duration.session)
        XCTAssertGreaterThan(duration.unlocking, duration.era)
    }
}
