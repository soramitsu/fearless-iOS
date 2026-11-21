import SoraFoundation
import UIKit
import XCTest
@testable import fearless

/// Brand kit v3's design pass gives cards a lit rim (gold on the upper left fading through pink, with an inner top
/// highlight): the wallet's balance card, the tab bar and the receive QR well on iOS, every card on Android and the send
/// review cards on the web. The iOS send screen's recipient, amount and network cards had none.
@MainActor
final class SendCardGlowTests: XCTestCase {
    /// Seconds to keep the screen up for `xcrun simctl io screenshot` (evidence only; unset in normal runs). Passed to
    /// the test host as `TEST_RUNNER_FW_SEND_GLOW_HOLD_SECONDS` in xcodebuild's environment.
    private static let holdKey = "FW_SEND_GLOW_HOLD_SECONDS"

    func testSendCardsWearTheLitRimInsideTheirBounds() throws {
        let screen = try SendGlowScreen(highContrast: false)
        defer { screen.close() }
        Self.holdIfRequested()

        for (name, card) in screen.cards {
            XCTAssertFalse(card.bounds.isEmpty, name)
            let rims = Self.rims(in: card.layer, depth: 1)
            XCTAssertEqual(rims.count, 1, "\(name) wears one lit rim")
            guard let rim = rims.first else { continue }
            XCTAssertFalse(rim.isHidden, name)
            XCTAssertEqual(rim.frame, card.bounds, "\(name): the rim follows the card")
            XCTAssertEqual(rim.cornerRadiusValue, card.resolvedCornerRadius, "\(name): the rim follows the corners")
            XCTAssertTrue(Self.isUnclipped(card), "\(name): no scroll view or container cuts the card or its rim")
        }
        XCTAssertEqual(Self.rims(in: screen.controller.view.layer).count, 3, "only the three cards are lit, not the buttons")
    }

    func testHighContrastKeepsTheCardsSolidStrokeWithoutTheRim() throws {
        let screen = try SendGlowScreen(highContrast: true)
        defer { screen.close() }

        for (name, card) in screen.cards {
            let rims = Self.rims(in: card.layer, depth: 1)
            XCTAssertEqual(rims.count, 1, name)
            XCTAssertEqual(rims.first?.isHidden, true, "\(name): high contrast shows the solid stroke alone")
        }
    }

    // MARK: - Helpers

    private static func holdIfRequested() {
        guard let value = ProcessInfo.processInfo.environment[holdKey], let seconds = TimeInterval(value), seconds > 0 else {
            return
        }
        RunLoop.main.run(until: Date().addingTimeInterval(min(seconds, 120)))
    }

    private static func rims(in layer: CALayer, depth: Int = .max) -> [FWLitRimLayer] {
        guard depth > 0 else { return [] }
        return (layer.sublayers ?? []).flatMap { sublayer -> [FWLitRimLayer] in
            let own = (sublayer as? FWLitRimLayer).map { [$0] } ?? []
            return own + (sublayer is FWLitRimLayer ? [] : rims(in: sublayer, depth: depth - 1))
        }
    }

    private static func isUnclipped(_ view: UIView) -> Bool {
        var ancestor = view.superview
        while let parent = ancestor {
            let frame = view.convert(view.bounds, to: parent)
            if parent.clipsToBounds || parent.layer.masksToBounds, !parent.bounds.insetBy(dx: -0.5, dy: -0.5).contains(frame) {
                return false
            }
            ancestor = parent.superview
        }
        return true
    }
}

/// The real send screen (`SendViewController` and its `SendViewLayout`) filled with a recipient-less DOT transfer, in a
/// window over the whole scene. The output does nothing.
@MainActor
final class SendGlowScreen {
    private final class Output: SendViewOutput {
        func didLoad(view _: SendViewInput) {}
        func didTapBackButton() {}
        func didTapContinueButton() {}
        func didTapScanButton() {}
        func didTapHistoryButton() {}
        func didTapPasteButton() {}
        func didTapSelectAsset() {}
        func didTapSelectNetwork() {}
        func searchTextDidChanged(_: String) {}
        func selectAmountPercentage(_: Float, validate _: Bool) {}
        func didEditAmount(_: Decimal) -> () -> Void { {} }
        func updateAmount(_: Decimal) {}
        func didSwitchSendAll(_: Bool) {}
    }

    private let output = Output()
    let controller: SendViewController
    let window: UIWindow

    var layout: SendViewLayout { controller.rootView }

    /// The recipient, amount and network cards: the surfaces the screen draws its cards with.
    var cards: [(String, TriangularedView)] {
        [
            ("recipient", layout.searchView.subviews.compactMap { $0 as? TriangularedView }.first),
            ("amount", layout.amountView.subviews.compactMap { $0 as? TriangularedView }.first),
            ("network", layout.selectNetworkView.triangularedBackgroundView)
        ].compactMap { name, card in card.map { (name, $0) } }
    }

    init(highContrast: Bool) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        if #available(iOS 17.0, *) {
            window.traitOverrides.accessibilityContrast = highContrast ? .high : .normal
        }
        let localization = try XCTUnwrap(LocalizationManager(localization: "en"))
        controller = SendViewController(initialData: .address(""), output: output, localizationManager: localization)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.loadViewIfNeeded()

        let icon = BundleImageViewModel(image: R.image.iconPolkadotAsset())
        controller.didReceive(assetBalanceViewModel: AssetBalanceViewModel(
            symbol: "DOT", balance: "12.5", fiatBalance: "$52.13", price: "$4.17", iconViewModel: icon, selectable: true
        ))
        controller.didReceive(selectNetworkViewModel: SelectNetworkViewModel(chainName: "Polkadot", iconViewModel: icon))
        controller.didReceive(feeViewModel: BalanceViewModel(amount: "0.0158 DOT", price: "$0.07"))
        controller.didStopFeeCalculation()
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        window.layoutIfNeeded()
    }

    func close() {
        window.endEditing(true)
        window.isHidden = true
        window.rootViewController = nil
    }
}
