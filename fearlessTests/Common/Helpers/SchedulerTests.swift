import XCTest
@testable import fearless
import Cuckoo

class SchedulerTests: XCTestCase {

    func testTriggerDelivered() {
        // given

        let delay: TimeInterval = 0.1

        final class TestDelegate: fearless.SchedulerDelegate {
            let fulfill: () -> Void
            init(fulfill: @escaping () -> Void) { self.fulfill = fulfill }
            func didTrigger(scheduler: fearless.SchedulerProtocol) { fulfill() }
        }
        let expectation = XCTestExpectation()
        let delegate = TestDelegate { expectation.fulfill() }
        let scheduler = Scheduler(with: delegate)

        // when

        scheduler.notifyAfter(delay)

        // then

        wait(for: [expectation], timeout: 10.0 * delay)
    }
}
