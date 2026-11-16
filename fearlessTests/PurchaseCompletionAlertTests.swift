import XCTest
import SoraFoundation
@testable import fearless

/// PurchaseWireframe.complete dismissed the purchase page and then presented the "purchase completed" alert from that
/// same page. A dismissed controller is out of the window, so UIKit refused the presentation and the alert never
/// appeared.
final class PurchaseCompletionAlertTests: XCTestCase {
    func testTheCompletionAlertIsShownByTheScreenThatOpenedThePurchase() throws {
        let root = UIViewController()
        let window = try CovJViewFixture.host(root)
        defer { window.isHidden = true }
        let page = CovJMxPurchaseView()
        let navigation = UINavigationController(rootViewController: page)
        root.present(navigation, animated: false)
        XCTAssertTrue(CovJWait.until { root.presentedViewController === navigation && !navigation.isBeingPresented })
        let manager = try XCTUnwrap(LocalizationManager(localization: "en"))

        PurchaseWireframe(localizationManager: manager).complete(from: page)

        XCTAssertTrue(CovJWait.until(timeout: 5) {
            root.presentedViewController.map { $0 !== navigation && !$0.isBeingPresented } ?? false
        })
        let alert = try XCTUnwrap(root.presentedViewController)
        alert.loadViewIfNeeded()
        let texts = CovHNftViews.texts(in: alert.view)
        XCTAssertTrue(texts.contains(R.string.localizable.buyCompleted(preferredLanguages: ["en"])), "\(texts)")
        XCTAssertNil(navigation.presentingViewController, "the purchase page is closed")
    }
}
