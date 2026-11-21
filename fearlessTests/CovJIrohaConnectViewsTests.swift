import XCTest
import UIKit
@testable import fearless

final class CovJIrohaConnectViewsTests: XCTestCase {
    func testConnectionPromptDisplaysClaimsAndRoutesActions() throws {
        let prompt = IrohaConnectPrompt(
            kind: .connection, appName: "Test dApp", appURL: URL(string: "https://example.invalid/path"),
            networkName: "Taira", accountID: "0123456789012345678901234567890123456789"
        )
        let controller = IrohaConnectPromptViewController(prompt: prompt)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let labels = CovJViewFixture.descendants(UILabel.self, in: controller.view)
        let text = labels.compactMap(\.text)
        XCTAssertTrue(text.contains("Connect your SORA wallet"))
        XCTAssertTrue(text.contains("Test dApp"))
        XCTAssertTrue(text.contains("example.invalid"))
        XCTAssertTrue(text.contains("012345678901…0123456789"))
        XCTAssertFalse(text.contains("SHA-256"))
        let permission = try XCTUnwrap(labels.first { $0.text == "Signs data supplied by this app. Fearless can't decode it." })
        XCTAssertEqual(permission.numberOfLines, 0)
        let buttons = CovJViewFixture.descendants(UIButton.self, in: controller.view)
        let approve = try XCTUnwrap(buttons.first { $0.configuration?.title == "Connect with PIN" })
        let reject = try XCTUnwrap(buttons.first { $0.configuration?.title == "Reject" })
        var approved = 0
        var rejected = 0
        controller.onApprove = { approved += 1 }
        controller.onReject = { rejected += 1 }
        reject.sendActions(for: .touchUpInside)
        XCTAssertEqual(rejected, 1)
        XCTAssertEqual(approved, 0)
        approve.sendActions(for: .touchUpInside)
        XCTAssertEqual(approved, 1)
        XCTAssertFalse(approve.isEnabled)
        XCTAssertFalse(reject.isEnabled)
        controller.setActionsEnabled(true)
        XCTAssertTrue(approve.isEnabled)
        XCTAssertTrue(reject.isEnabled)
        XCTAssertGreaterThanOrEqual(approve.frame.height, 54)
        XCTAssertEqual(controller.modalPresentationStyle, .fullScreen)
    }

    func testSignaturePromptDisplaysPayloadFingerprintWithoutOrigin() throws {
        let prompt = IrohaConnectPrompt(
            kind: .signature(payload: Data("abc".utf8)),
            appName: "Signer",
            appURL: nil,
            networkName: "Taira",
            accountID: "alice"
        )
        XCTAssertEqual(prompt.payloadByteCount, 3)
        XCTAssertEqual(prompt.payloadDigest, "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
        let controller = IrohaConnectPromptViewController(prompt: prompt)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let texts = CovJViewFixture.descendants(UILabel.self, in: controller.view).compactMap(\.text)
        XCTAssertTrue(texts.contains("Approve contract signature"))
        XCTAssertTrue(texts.contains("3 bytes"))
        XCTAssertTrue(texts.contains("ba7816bf8f01cfea…ff61f20015ad"))
        XCTAssertTrue(texts.contains("alice"))
        XCTAssertFalse(texts.contains("CLAIMED ORIGIN"))
        let button = CovJViewFixture.descendants(UIButton.self, in: controller.view).first { $0.configuration?.title == "Review with PIN" }
        XCTAssertNotNil(button)
        controller.setActionsEnabled(false)
        XCTAssertEqual(button?.isEnabled, false)
    }

    func testPromptAccountBoundaryAndURLWithoutHost() {
        XCTAssertEqual(IrohaConnectPrompt.shortenedAccountID(String(repeating: "a", count: 24)), String(repeating: "a", count: 24))
        XCTAssertEqual(IrohaConnectPrompt.shortenedAccountID(String(repeating: "b", count: 25)), "bbbbbbbbbbbb…bbbbbbbbbb")
        let prompt = IrohaConnectPrompt(
            kind: .connection,
            appName: "App",
            appURL: URL(string: "urn:example:test"),
            networkName: "Taira",
            accountID: "short"
        )
        XCTAssertNil(prompt.payloadDigest)
        XCTAssertNil(prompt.payloadByteCount)
        let controller = IrohaConnectPromptViewController(prompt: prompt)
        controller.loadViewIfNeeded()
        XCTAssertTrue(CovJViewFixture.descendants(UILabel.self, in: controller.view).contains { $0.text == "urn:example:test" })
    }

    func testLandingScreenRoutesScanPasteAndCloseWithoutClipboardAccess() throws {
        let controller = IrohaConnectLandingViewController()
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        var actions: [String] = []
        controller.onScan = { actions.append("scan") }
        controller.onPaste = { actions.append("paste") }
        controller.onClose = { actions.append("close") }
        let buttons = CovJViewFixture.descendants(UIButton.self, in: controller.view)
        let scan = try XCTUnwrap(buttons.first { $0.configuration?.title == "Scan pairing QR" })
        let paste = try XCTUnwrap(buttons.first { $0.configuration?.title == "Paste pairing link" })
        scan.sendActions(for: .touchUpInside)
        paste.sendActions(for: .touchUpInside)
        let close = try XCTUnwrap(controller.navigationItem.leftBarButtonItem)
        try UIApplication.shared.sendAction(XCTUnwrap(close.action), to: close.target, from: close, for: nil)
        XCTAssertEqual(actions, ["scan", "paste", "close"])
        XCTAssertEqual(controller.title, "IrohaConnect")
        XCTAssertGreaterThanOrEqual(scan.frame.height, 54)
        XCTAssertEqual(scan.frame.width, paste.frame.width, accuracy: 0.5)
        XCTAssertTrue(CovJViewFixture.descendants(UILabel.self, in: controller.view).contains { $0.accessibilityLabel == "Sakura" })
        let background = try XCTUnwrap(controller.view.layer.sublayers?.first as? CAGradientLayer)
        XCTAssertEqual(background.frame, controller.view.bounds)
    }

    func testSakuraDecorationConfiguresOnceAndTracksBounds() throws {
        let view = IrohaConnectSakuraView()
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertTrue(view.accessibilityElementsHidden)
        view.didMoveToWindow()
        XCTAssertTrue(view.layer.sublayers.or([]).isEmpty)
        let window = try CovJViewFixture.host(view)
        defer { window.isHidden = true }
        let count = view.layer.sublayers.or([]).count
        XCTAssertGreaterThan(count, 0)
        view.didMoveToWindow()
        XCTAssertEqual(view.layer.sublayers.or([]).count, count)
        NotificationCenter.default.post(name: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil)
        XCTAssertEqual(view.layer.sublayers.or([]).count, count)
        if let emitter = view.layer.sublayers?.compactMap({ $0 as? CAEmitterLayer }).first {
            XCTAssertEqual(emitter.emitterPosition, CGPoint(x: view.bounds.midX, y: -24))
            XCTAssertEqual(emitter.emitterSize.width, view.bounds.width)
            XCTAssertEqual(emitter.emitterCells?.count, 1)
            XCTAssertGreaterThan(emitter.emitterCells?.first?.birthRate ?? 0, 0)
        }
    }
}
