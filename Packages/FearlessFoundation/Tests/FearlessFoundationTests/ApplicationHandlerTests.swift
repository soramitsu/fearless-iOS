import UIKit
import XCTest
@testable import FearlessFoundation

final class ApplicationHandlerTests: XCTestCase {
    func testNotifications_whenPosted_thenDelegateReceivesLifecycleEvents() {
        let delegate = ApplicationDelegateRecorder()
        let handler = ApplicationHandler(with: delegate)

        NotificationCenter.default.post(name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)

        XCTAssertEqual(delegate.events, [
            "willResignActive",
            "didBecomeActive",
            "willEnterForeground",
            "didEnterBackground"
        ])
        _ = handler
    }
}

private final class ApplicationDelegateRecorder: NSObject, ApplicationHandlerDelegate {
    private(set) var events: [String] = []

    func didReceiveWillResignActive(notification _: Notification) {
        events.append("willResignActive")
    }

    func didReceiveDidBecomeActive(notification _: Notification) {
        events.append("didBecomeActive")
    }

    func didReceiveWillEnterForeground(notification _: Notification) {
        events.append("willEnterForeground")
    }

    func didReceiveDidEnterBackground(notification _: Notification) {
        events.append("didEnterBackground")
    }
}
