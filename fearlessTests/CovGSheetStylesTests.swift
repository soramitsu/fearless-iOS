import Foundation
import MessageUI
import UIKit
import XCTest
@testable import fearless

final class CovGSheetStylesTests: XCTestCase {
    func testActionStylesPairExpectedBackgroundAndTitleColors() throws {
        let white = try XCTUnwrap(R.color.colorWhite())
        let pink = try XCTUnwrap(R.color.colorPink())
        let semiBlack = try XCTUnwrap(R.color.colorSemiBlack())
        let white8 = try XCTUnwrap(R.color.colorWhite8())
        let styles: [(SheetAlertPresentableActionStyle, UIColor, UIColor)] = [
            (.defaultStyle, white8, white), (.warningStyle, white8, pink), (.pinkBackgroundWhiteText, pink, white),
            (.grayBackgroundPinkText, semiBlack, pink), (.grayBackgroundWhiteText, semiBlack, white),
            (.clearBackgroundWhiteText, .clear, white), (.clearBackgroundPinkText, .clear, pink),
        ]
        for (style, background, title) in styles {
            XCTAssertEqual(style.backgroundColor, background)
            XCTAssertEqual(style.titleColor, title)
        }
        var handled = 0
        let action = SheetAlertPresentableAction(title: "Proceed", style: .warningStyle) { handled += 1 }
        action.handler?()
        XCTAssertEqual(handled, 1)
        XCTAssertEqual(action.title, "Proceed")
        XCTAssertFalse(action.handlerAfterDismissal)
        XCTAssertEqual(action.style.titleColor, pink)
    }

    func testInfoSheetIsPresentedOnlyWhenControllerExists() throws {
        let presenter = CovGInfoPresenter()
        let view = CovGInfoHost()
        presenter.presentInfo(message: "Information", title: "Info", from: view)
        let sheet = try XCTUnwrap(view.captured as? SheetAletViewController)
        XCTAssertEqual(sheet.modalPresentationStyle, .custom)
        XCTAssertNotNil(sheet.modalTransitioningFactory)
        view.captured = nil
        presenter.presentInfo(message: nil, title: "Info", from: nil)
        XCTAssertNil(view.captured)
    }

    func testEmailComposerIsPresentedOnlyWhenTheDeviceCanSendMail() {
        let view = CovGInfoHost()
        let message = SocialMessage(body: "Body", subject: "Subject", recepients: ["support@fixture.invalid"])
        let presented = CovGEmailWriter().writeEmail(with: message, from: view, completionHandler: nil)
        if MFMailComposeViewController.canSendMail() {
            XCTAssertTrue(presented)
            XCTAssertTrue(view.captured is MFMailComposeViewController)
        } else {
            XCTAssertFalse(presented)
            XCTAssertNil(view.captured)
        }
    }

    func testKeyboardHandlerIsCreatedOnceAndCleared() {
        let adoptable = CovGKeyboardAdoptable()
        adoptable.setupKeyboardHandler()
        let first = adoptable.keyboardHandler
        XCTAssertNotNil(first)
        adoptable.setupKeyboardHandler()
        XCTAssertTrue(adoptable.keyboardHandler === first)
        adoptable.clearKeyboardHandler()
        XCTAssertNil(adoptable.keyboardHandler)
    }
}

private final class CovGInfoPresenter: SheetAlertPresentable {
    func present(error _: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        false
    }
}

private final class CovGInfoHost: UIViewController, ControllerBackedProtocol {
    var controller: UIViewController {
        self
    }

    var captured: UIViewController?
    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        captured = viewControllerToPresent
        completion?()
    }
}

private struct CovGEmailWriter: EmailPresentable {}

private final class CovGKeyboardAdoptable: KeyboardAdoptable {
    var keyboardHandler: FearlessKeyboardHandler?
    func updateWhileKeyboardFrameChanging(_: CGRect) {}
}
