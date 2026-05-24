import XCTest
@testable import FearlessFoundation

final class DayChangeHandlerTests: XCTestCase {
    func testCalendarDayChangedNotification_whenPosted_thenDelegateReceivesChangeOnMainQueue() {
        let delegate = DayChangeDelegateRecorder()
        let handler = DayChangeHandler()
        handler.delegate = delegate

        let expectation = expectation(description: "day change delegate")
        delegate.onChange = {
            XCTAssertTrue(Thread.isMainThread)
            expectation.fulfill()
        }

        NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(delegate.changeCount, 1)
        _ = handler
    }
}

private final class DayChangeDelegateRecorder: DayChangeHandlerDelegate {
    var onChange: (() -> Void)?
    private(set) var changeCount = 0

    func handlerDidReceiveChange(_: DayChangeHandlerProtocol) {
        changeCount += 1
        onChange?()
    }
}
