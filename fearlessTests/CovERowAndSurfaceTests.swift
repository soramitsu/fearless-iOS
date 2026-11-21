@testable import fearless
import UIKit
import XCTest

@MainActor
final class CovERowAndSurfaceTests: XCTestCase {
    func testRowFlashesOnlyChangedValuesOfTheSameItemAndDebugTickBumpsTheLastDigit() {
        let row = FWRowSunlit()
        let label = UILabel()
        label.text = "1.20"
        let window = CovEHost.window(for: label, frame: CGRect(x: 16, y: 100, width: 120, height: 20))
        defer { CovEHost.close(window) }
        let settled = UIColor.white
        label.textColor = settled
        let animates = FWMotionPolicy.current(effects: .shared).style(for: .priceChange).animates

        row.show(value: "1.20", for: "dot", flashing: label, settledColor: settled)
        row.show(value: "1.20", for: "dot", flashing: label, settledColor: settled)
        XCTAssertEqual(label.textColor, settled, "the same value does not flash")
        row.show(value: "9.99", for: "ksm", flashing: label, settledColor: settled)
        XCTAssertEqual(label.textColor, settled, "a different item does not flash")

        row.show(value: "10.50", for: "ksm", flashing: label, settledColor: settled)
        XCTAssertEqual(label.textColor, animates ? FWSunlit.Palette.priceUp : settled)
        label.textColor = settled

        #if DEBUG
            assertDebugTick(row: row, label: label, settled: settled)
        #endif
    }

    #if DEBUG
        private func assertDebugTick(row: FWRowSunlit, label: UILabel, settled: UIColor) {
            XCTAssertEqual(FWRowSunlit.bumped("$12"), "$13")
            XCTAssertEqual(FWRowSunlit.bumped("1.2 DOT"), "1.3 DOT")
            XCTAssertNil(FWRowSunlit.bumped("1.29"), "a carry is not attempted")
            XCTAssertNil(FWRowSunlit.bumped("none"))

            label.text = "10.50"
            row.observeDebugTick(label: label, settledColor: settled)
            row.observeDebugTick(label: label, settledColor: settled)
            NotificationCenter.default.post(name: FWShikibanDebugSeams.tickNotification, object: nil)
            XCTAssertTrue(CovEHost.spin(until: { label.text == "10.51" }), "the tick seam shows the next value")
            NotificationCenter.default.post(name: FWShikibanDebugSeams.tickNotification, object: nil)
            XCTAssertTrue(CovEHost.spin(until: { label.text == "10.52" }), "one observer, one bump per tick")
        }
    #endif

    func testRowSurfacesUseRaisedElevationAndTheWellSitsBehindTheIcon() {
        let surface = FWRowSunlit.rowSurface()
        XCTAssertFalse(surface.isUserInteractionEnabled)
        let background = FWRowSunlit.rowBackground()
        XCTAssertEqual(background.fwElevation, .raised1)
        XCTAssertEqual(background.fwCornerRadius, FWSunlit.Radius.row)

        let container = UIView()
        let icon = UIImageView()
        container.addSubview(icon)
        let row = FWRowSunlit()
        row.installWell(behind: icon, in: container, growth: 8)
        XCTAssertEqual(container.subviews.firstIndex(of: row.iconWell), 0)
        icon.frame = CGRect(x: 10, y: 10, width: 24, height: 24)
        icon.translatesAutoresizingMaskIntoConstraints = true
        container.frame = CGRect(x: 0, y: 0, width: 100, height: 60)
        container.layoutIfNeeded()
        XCTAssertEqual(row.iconWell.frame.size, CGSize(width: 32, height: 32))
        XCTAssertEqual(row.iconWell.center, icon.center)
    }

    func testLoadingButtonStyleHidesTheTitleOnAnInsetSurface() throws {
        let button = TriangularedButton()
        button.imageWithTitleView?.title = "Confirm"
        button.applyLoadingStyle()
        let surface = try XCTUnwrap(button.triangularedView)
        XCTAssertEqual(button.fwStyleRole, .other)
        XCTAssertEqual(surface.fwElevation, .inset)
        XCTAssertTrue(surface.fwInteractive)
        XCTAssertEqual(surface.fillColor, FWSunlit.Palette.backgroundDeep)
        XCTAssertEqual(surface.strokeColor, .clear)
        XCTAssertEqual(button.imageWithTitleView?.titleColor, .clear)
        XCTAssertEqual(button.contentOpacityWhenDisabled, 1)
    }

    func testFilledDoubleSymbolPinsBothImagesToTheRequestedSize() throws {
        let view = PolkaswapDoubleSymbolView(imageSize: CGSize(width: 20, height: 20), mode: .filled)
        let fitting = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        XCTAssertEqual(fitting, CGSize(width: 18, height: 20), "two 20 pt images overlapping by 22 pt")
        let window = CovEHost.window(for: view, frame: CGRect(origin: CGPoint(x: 16, y: 100), size: fitting))
        defer { CovEHost.close(window) }
        view.bind(viewModel: PolkaswapDoubleSymbolViewModel(
            leftViewModel: nil,
            rightViewModel: nil,
            leftShadowColor: UIColor.red.cgColor,
            rightShadowColor: UIColor.blue.cgColor
        ))
        view.layoutIfNeeded()
        let left = try XCTUnwrap(CovEFind.mirror(view, "leftImageView", as: UIImageView.self))
        let leftContainer = try XCTUnwrap(CovEFind.mirror(view, "leftContainer", as: UIView.self))
        XCTAssertEqual(left.frame.size, CGSize(width: 20, height: 20))
        XCTAssertEqual(left.frame, leftContainer.bounds, "filled images take the whole container")
        XCTAssertEqual(leftContainer.layer.cornerRadius, leftContainer.frame.height / 2)
        XCTAssertEqual(leftContainer.layer.shadowColor, UIColor.red.cgColor)
        XCTAssertNil(leftContainer.backgroundColor, "only centered symbols sit on a black disc")
    }

    func testBlurViewForwardsSideLengthAndFillsItsBounds() throws {
        let view = TriangularedBlurView()
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 200, height: 60))
        defer { CovEHost.close(window) }
        view.sideLength = 14
        XCTAssertEqual(view.overlayView.sideLength, 14)
        XCTAssertEqual(view.blurMaskView?.sideLength ?? 14, 14)
        view.frame.size = CGSize(width: 240, height: 80)
        view.layoutIfNeeded()
        XCTAssertEqual(view.overlayView.frame, view.bounds)
        if let blur = view.blurView {
            XCTAssertEqual(blur.frame, view.bounds)
        }
    }

    func testMnemonicHeaderPlacesTheTitleAfterTheIconAndHonoursSpacing() throws {
        let view = TitledMnemonicView(frame: .zero)
        let window = CovEHost.window(for: view, frame: CGRect(x: 16, y: 100, width: 358, height: 300))
        defer { CovEHost.close(window) }
        view.titleLabel.text = "Your secret phrase"
        view.verticalSpacing = 10
        view.layoutIfNeeded()
        XCTAssertEqual(view.titleLabel.frame.minX, 0, "without an icon the title starts at the edge")
        XCTAssertEqual(view.contentView.frame.minY, view.titleLabel.frame.maxY + 10, accuracy: 0.5)

        view.iconView.image = UIImage(systemName: "lock")
        view.horizontalSpacing = 5
        view.layoutIfNeeded()
        XCTAssertEqual(view.titleLabel.frame.minX, view.iconView.frame.maxX + 5, accuracy: 0.5)
        XCTAssertGreaterThan(view.intrinsicContentSize.height, 10)
    }
}
