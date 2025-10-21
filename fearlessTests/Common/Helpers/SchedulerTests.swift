import XCTest
@testable import fearless
import Cuckoo

class SchedulerTests: XCTestCase {

    func testTriggerDelivered() {
        // given

        let delay: TimeInterval = 0.1

        class TestDelegate: SchedulerDelegate {
            let exp: XCTestExpectation
            init(exp: XCTestExpectation) { self.exp = exp }
            func didTrigger(scheduler: SchedulerProtocol) { exp.fulfill() }
        }

        let expectation = XCTestExpectation()
        let delegate = TestDelegate(exp: expectation)
        let scheduler = Scheduler(with: delegate)

        // when

        scheduler.notifyAfter(delay)

        // then

        wait(for: [expectation], timeout: 10.0 * delay)
    }
}
