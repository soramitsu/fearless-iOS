import XCTest
@testable import fearless

class StakingDurationOperationFactoryTests: XCTestCase {
    func testWestend() {
        do {
            // given

            // Build a minimal stub with a coding factory suitable for tests
            let codingFactory = try WestendStubHelper.makeCoderFactory()
            let runtimeService = RuntimeCodingServiceStub(factory: codingFactory)
            let operationFactory = StakingDurationOperationFactory()

            // when

            let operationWrapper = operationFactory.createDurationOperation(from: runtimeService)

            OperationQueue().addOperations(operationWrapper.allOperations, waitUntilFinished: true)

            let duration = try operationWrapper.targetOperation.extractResultData(throwing: fearless.BaseOperationError.parentOperationCancelled)

            XCTAssertEqual(duration.era, 6 * 3600)
            XCTAssertEqual(duration.unlocking, 28 * 6 * 3600)
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }
}
