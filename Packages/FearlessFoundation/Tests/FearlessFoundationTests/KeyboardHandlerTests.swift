import UIKit
import XCTest
@testable import FearlessFoundation

final class KeyboardHandlerTests: XCTestCase {
    func testKeyboardNotifications_whenPosted_thenDelegateReceivesEvents() {
        let delegate = KeyboardDelegateRecorder()
        let handler = KeyboardHandler(with: delegate)

        NotificationCenter.default.post(name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidShowNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidHideNotification, object: nil)
        NotificationCenter.default.post(name: UIResponder.keyboardDidChangeFrameNotification, object: nil)

        XCTAssertEqual(delegate.events, [
            "willShow",
            "didShow",
            "willHide",
            "didHide",
            "didChangeFrame"
        ])
        _ = handler
    }

    func testWillChangeFrameNotification_whenFrameInfoProvided_thenAnimatesAndNotifiesDelegate() {
        let delegate = KeyboardDelegateRecorder()
        let handler = KeyboardHandler(with: delegate)
        var animatedFrame: CGRect?
        let expectedFrame = CGRect(x: 0, y: 100, width: 320, height: 216)

        handler.animateOnFrameChange = { frame in
            animatedFrame = frame
        }

        NotificationCenter.default.post(
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
            userInfo: [
                UIResponder.keyboardFrameEndUserInfoKey: NSValue(cgRect: expectedFrame),
                UIResponder.keyboardAnimationDurationUserInfoKey: TimeInterval(0),
                UIResponder.keyboardAnimationCurveUserInfoKey: UIView.AnimationCurve.easeInOut.rawValue
            ]
        )

        XCTAssertEqual(animatedFrame, expectedFrame)
        XCTAssertEqual(delegate.events, ["willChangeFrame"])
        _ = handler
    }
}

private final class KeyboardDelegateRecorder: NSObject, KeyboardHandlerDelegate {
    private(set) var events: [String] = []

    func keyboardWillShow(notification _: Notification) {
        events.append("willShow")
    }

    func keyboardDidShow(notification _: Notification) {
        events.append("didShow")
    }

    func keyboardWillHide(notification _: Notification) {
        events.append("willHide")
    }

    func keyboardDidHide(notification _: Notification) {
        events.append("didHide")
    }

    func keyboardWillChangeFrame(notification _: Notification) {
        events.append("willChangeFrame")
    }

    func keyboardDidChangeFrame(notification _: Notification) {
        events.append("didChangeFrame")
    }
}
