import XCTest
@testable import fearless
import Cuckoo

class SchedulerTests: XCTestCase {

    func testTriggerDelivered() {
        // given

        let delay: TimeInterval = 0.1

        let delegate = MockSchedulerDelegate()
        let scheduler = Scheduler(with: delegate)

        let expectation = XCTestExpectation()

        stub(delegate) { stub in
            when(stub).didTrigger(scheduler: any()).then { _ in
                expectation.fulfill()
            }
        }

        // when

        scheduler.notifyAfter(delay)

        // then

        wait(for: [expectation], timeout: 10.0 * delay)
    }
}
