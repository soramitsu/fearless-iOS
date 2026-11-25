import XCTest
import UIKit
@testable import fearless

final class CovJIrohaConnectViewsTests: XCTestCase {
    func testConnectionPromptDisplaysClaimsAndRoutesActions() throws {
        let prompt = IrohaConnectPrompt(
            kind: .connection(permissions: IrohaConnectPermissions(methods: ["sign_transaction", "sign_raw"], events: [], resources: nil)),
            appName: "Test dApp", appURL: URL(string: "https://example.invalid/path"),
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
        XCTAssertTrue(text.contains("sign_transaction, sign_raw"))
        XCTAssertFalse(text.contains("PAYLOAD HASH"))
        let signing = try XCTUnwrap(labels.first { $0.text?.hasPrefix("You approve every transaction with your PIN.") == true })
        XCTAssertEqual(signing.numberOfLines, 0)
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

    func testTransferPromptShowsTheDecodedTransfer() throws {
        let reviewed = IrohaConnectWebVectors.reviewedTransaction("transfer scoped with nonce, metadata and both limits")
        let review = reviewed.review
        let prompt = IrohaConnectPrompt(kind: .transaction(review), appName: "Signer", appURL: nil, networkName: "Taira Testnet", accountID: review.authority)
        XCTAssertTrue(prompt.isTransaction)
        let rows = Dictionary(prompt.rows.map { ($0.label, $0.value) }, uniquingKeysWith: { first, _ in first })
        XCTAssertEqual(rows["SEND"], "12.5 XOR")
        XCTAssertEqual(rows["TO"], review.transfer?.destination)
        XCTAssertEqual(rows["SCOPE"], "dataspace:7")
        XCTAssertEqual(rows["MAX FEE"], "0.1 XOR")
        XCTAssertEqual(rows["MAX GAS FEE"], "3 XOR")
        XCTAssertEqual(rows["GAS LIMIT"], "50000")
        XCTAssertEqual(rows["VALID FOR"], "100 s after creation")
        XCTAssertEqual(rows["METADATA"], review.metadata)
        XCTAssertTrue(rows["METADATA"]?.contains("\\u{202E}") == true, "bidi controls are shown escaped")
        XCTAssertNil(rows["CLAIMED ORIGIN"])

        let controller = IrohaConnectPromptViewController(prompt: prompt)
        let window = try CovJViewFixture.host(controller)
        defer { window.isHidden = true }
        let labels = CovJViewFixture.descendants(UILabel.self, in: controller.view)
        XCTAssertTrue(labels.contains { $0.text == "Approve transfer" })
        let destination = try XCTUnwrap(labels.first { $0.text == review.transfer?.destination })
        XCTAssertEqual(destination.numberOfLines, 0, "the destination is never truncated")
        let button = CovJViewFixture.descendants(UIButton.self, in: controller.view).first { $0.configuration?.title == "Sign with PIN" }
        XCTAssertNotNil(button)
        controller.setActionsEnabled(false)
        XCTAssertEqual(button?.isEnabled, false)
    }

    func testContractCallPromptShowsEveryCall() {
        let review = IrohaConnectWebVectors.reviewedTransaction("two contract calls").review
        let prompt = IrohaConnectPrompt(kind: .transaction(review), appName: "Signer", appURL: nil, networkName: "Taira Testnet", accountID: review.authority)
        XCTAssertEqual(prompt.title, "Approve contract call")
        let rows = prompt.rows
        XCTAssertEqual(rows.filter { $0.label.hasSuffix("METHOD") }.map(\.value), ["approve", "place_order"])
        XCTAssertEqual(rows.first { $0.label == "CALL 1 ARGUMENTS" }?.value, "None")
        XCTAssertEqual(rows.first { $0.label == "CALL 2 ARGUMENTS" }?.value.hasPrefix("200 bytes, SHA-256 "), true)
        XCTAssertEqual(rows.last?.label, "PAYLOAD HASH")
    }

    func testPromptAccountBoundaryAndURLWithoutHost() {
        XCTAssertEqual(IrohaConnectPrompt.shortenedAccountID(String(repeating: "a", count: 24)), String(repeating: "a", count: 24))
        XCTAssertEqual(IrohaConnectPrompt.shortenedAccountID(String(repeating: "b", count: 25)), "bbbbbbbbbbbb…bbbbbbbbbb")
        let prompt = IrohaConnectPrompt(
            kind: .connection(permissions: nil),
            appName: "App",
            appURL: URL(string: "urn:example:test"),
            networkName: "Taira",
            accountID: "short"
        )
        XCTAssertFalse(prompt.isTransaction)
        XCTAssertEqual(prompt.rows.first { $0.label == "ASKS TO" }?.value, "Any request")
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
