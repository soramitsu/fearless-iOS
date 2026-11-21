import Foundation
import SoraFoundation
import UIKit
import XCTest

@testable import fearless

final class CovDAdjustmentTapSpy: PolkaswapAdjustmentViewOutput {
    private(set) var taps: [String] = []

    func didLoad(view _: PolkaswapAdjustmentViewInput) { taps.append("load") }
    func didTapBackButton() { taps.append("back") }
    func didTapMarketButton() { taps.append("market") }
    func didTapSelectFromAsset() { taps.append("from") }
    func didTapSelectToAsset() { taps.append("to") }
    func didTapSwitchInputsButton() { taps.append("switch") }
    func didTapMinReceiveInfo() { taps.append("minReceive") }
    func didTapNetworkFeeInfo() { taps.append("networkFee") }
    func didTapPreviewButton() { taps.append("preview") }
    func selectFromAmountPercentage(_: Float) {}
    func updateFromAmount(_: Decimal) {}
    func selectToAmountPercentage(_: Float) {}
    func updateToAmount(_: Decimal) {}
    func viewDidAppear() { taps.append("appear") }
}

final class CovDAdjustmentControlsTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    func testEveryControlOnTheSwapScreenReachesThePresenter() throws {
        let output = CovDAdjustmentTapSpy()
        let controller = PolkaswapAdjustmentViewController(
            output: output, bannersViewController: UIViewController(), localizationManager: LocalizationManager.shared
        )
        window = try CovDFixtures.host(controller)
        XCTAssertTrue(CovDFixtures.spin { output.taps.contains("appear") })
        let layout = controller.rootView
        layout.marketButton.sendActions(for: .touchUpInside)
        layout.switchSwapButton.sendActions(for: .touchUpInside)
        layout.previewButton.sendActions(for: .touchUpInside)
        layout.backButton.sendActions(for: .touchUpInside)
        layout.swapFromInputView.selectHandler?()
        layout.swapToInputView.selectHandler?()
        XCTAssertFalse(layout.minMaxReceivedView.titleLabel.gestureRecognizers?.isEmpty ?? true)
        XCTAssertFalse(layout.networkFeeView.titleLabel.gestureRecognizers?.isEmpty ?? true)
        controller.perform(NSSelectorFromString("handleTapMinReceiveInfo"))
        controller.perform(NSSelectorFromString("handleTapNetworkFeeInfo"))
        XCTAssertEqual(
            output.taps.filter { !["load", "appear"].contains($0) },
            ["market", "switch", "preview", "back", "from", "to", "minReceive", "networkFee"]
        )
    }

    func testLiquidityScreensForwardInfoAndPreviewTaps() throws {
        let output = CovDLiquidityTapSpy()
        let supply = LiquidityPoolSupplyViewController(output: output, localizationManager: LocalizationManager.shared)
        window = try CovDFixtures.host(supply)
        for selector in ["handleTapApyInfo", "handleTapFeeInfo", "handleTapPreviewButton", "handleTapBackButton"] {
            supply.perform(NSSelectorFromString(selector))
        }
        XCTAssertEqual(output.taps, ["apy", "fee", "preview", "back"])

        let remove = LiquidityPoolRemoveLiquidityViewController(output: output, localizationManager: LocalizationManager.shared)
        window?.rootViewController = remove
        remove.loadViewIfNeeded()
        for selector in ["handleTapFeeInfo", "handleTapPreviewButton", "handleTapBackButton"] {
            remove.perform(NSSelectorFromString(selector))
        }
        XCTAssertEqual(output.taps.suffix(3), ["fee", "preview", "back"])
    }
}

final class CovDLiquidityTapSpy: LiquidityPoolSupplyViewOutput, LiquidityPoolRemoveLiquidityViewOutput {
    private(set) var taps: [String] = []

    func didLoad(view _: LiquidityPoolSupplyViewInput) {}
    func didLoad(view _: LiquidityPoolRemoveLiquidityViewInput) {}
    func handleViewAppeared() {}
    func didTapBackButton() { taps.append("back") }
    func didTapApyInfo() { taps.append("apy") }
    func didTapPreviewButton() { taps.append("preview") }
    func selectFromAmountPercentage(_: Float) {}
    func updateFromAmount(_: Decimal) {}
    func selectToAmountPercentage(_: Float) {}
    func updateToAmount(_: Decimal) {}
    func didTapFeeInfo() { taps.append("fee") }
}
