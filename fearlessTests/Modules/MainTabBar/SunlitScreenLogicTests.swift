@testable import fearless
import enum SSFModels.NetworkConstants
import SSFUtils
import SnapKit
import UIKit
import XCTest

/// The wallet home's sync indicator reads chain socket states through `WalletSyncUpdate`.
final class WalletHomeSyncTests: XCTestCase {
    func testSocketStatesMapToSyncConnections() {
        let limit = NetworkConstants.websocketReconnectAttemptsLimit
        XCTAssertEqual(WalletSyncUpdate.connection(for: .connected), .connected)
        XCTAssertEqual(WalletSyncUpdate.connection(for: .notConnected), .connecting)
        XCTAssertEqual(WalletSyncUpdate.connection(for: .notReachable), .unreachable)
        XCTAssertEqual(WalletSyncUpdate.connection(for: .connecting(attempt: 1)), .connecting)
        XCTAssertEqual(WalletSyncUpdate.connection(for: .waitingReconnection(attempt: limit)), .connecting)
        XCTAssertEqual(WalletSyncUpdate.connection(for: .connecting(attempt: limit + 1)), .unreachable)
        XCTAssertEqual(WalletSyncUpdate.connection(for: .waitingReconnection(attempt: limit + 1)), .unreachable)
    }
}

/// The tab bar's light well: where it shows and where it sits, for both tab bar generations (before iOS 26
/// the app draws the selection; from iOS 26 the system does).
final class TabBarSunlitWellTests: XCTestCase {
    func testWellShowsOnlyWhereTheSystemDrawsNoSelectionAndNeverUnderPolkaswap() {
        for destination in MainTabBarDestination.allCases {
            XCTAssertEqual(
                TabBarSunlitWell.showsWell(selectedIndex: destination.rawValue, systemDrawsSelection: false),
                destination != .polkaswap,
                "\(destination)"
            )
            XCTAssertFalse(TabBarSunlitWell.showsWell(selectedIndex: destination.rawValue, systemDrawsSelection: true))
        }
        if #available(iOS 26.0, *) {
            XCTAssertTrue(TabBarSunlitWell.systemDrawsSelection)
        } else {
            XCTAssertFalse(TabBarSunlitWell.systemDrawsSelection)
        }
    }

    func testWellCentresUnderEachTabOnTheCapsuleMidline() {
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 83)
        let capsule = TabBarBackgroundView.capsuleFrame(in: bounds, bottomInset: 34)
        let slot = bounds.width / CGFloat(MainTabBarDestination.allCases.count)
        for destination in MainTabBarDestination.allCases {
            let center = TabBarSunlitWell.wellCenter(in: bounds, bottomInset: 34, selectedIndex: destination.rawValue)
            XCTAssertEqual(center.x, slot * (CGFloat(destination.rawValue) + 0.5), accuracy: 0.001)
            XCTAssertEqual(center.y, capsule.midY - 2, accuracy: 0.001)
            let well = CGRect(
                x: center.x - FWTabWellView.size.width / 2,
                y: center.y - FWTabWellView.size.height / 2,
                width: FWTabWellView.size.width,
                height: FWTabWellView.size.height
            )
            XCTAssertTrue(capsule.contains(well), "\(destination): \(well) outside \(capsule)")
        }
    }
}

@MainActor
final class WalletHomeActionLayoutTests: XCTestCase {
    func testHomeActionsRemainReadableAndReachableAcrossLocalesAndLiveTextSizes() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let controller = UIViewController()
        let layout = WalletMainContainerViewLayout()
        controller.view = layout
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        for category: UIContentSizeCategory in [.large, .accessibilityExtraExtraExtraLarge, .large] {
            if #available(iOS 17.0, *) {
                window.traitOverrides.preferredContentSizeCategory = category
            }
            for language in ["en", "ru", "ja", "zh-Hans", "id", "pt-PT", "tr", "vi"] {
                layout.locale = Locale(identifier: language)
                window.layoutIfNeeded()
                layout.layoutIfNeeded()
                try await Task.sleep(nanoseconds: 20_000_000)
                window.layoutIfNeeded()
                for button in layout.sunlit.actionButtons {
                    let measure = UILabel()
                    measure.numberOfLines = 0
                    measure.font = button.titleLabel.font
                    measure.text = button.titleLabel.text
                    let expected = measure.sizeThatFits(CGSize(
                        width: button.titleLabel.bounds.width, height: .greatestFiniteMagnitude
                    ))
                    XCTAssertLessThanOrEqual(
                        expected.height,
                        button.titleLabel.bounds.height + 1,
                        "Complete action caption: \(language), \(category), \(measure.text ?? "")"
                    )
                    XCTAssertGreaterThanOrEqual(button.bounds.width, 44)
                    XCTAssertGreaterThanOrEqual(button.bounds.height, 44)
                    let scroll = layout.headerScrollView
                    scroll.scrollRectToVisible(button.convert(button.bounds, to: scroll), animated: false)
                    layout.layoutIfNeeded()
                    let frame = button.convert(button.bounds, to: layout)
                    let viewport = scroll.convert(scroll.bounds, to: layout)
                    XCTAssertGreaterThanOrEqual(frame.minY, viewport.minY - 1)
                    XCTAssertLessThanOrEqual(frame.maxY, viewport.maxY + 1)
                    let hit = window.hitTest(button.convert(CGPoint(x: button.bounds.midX, y: button.bounds.midY), to: window), with: nil)
                    XCTAssertTrue(hit === button || hit?.isDescendant(of: button) == true)
                }
            }
        }
    }
}

@MainActor
final class PortfolioLensGeometryTests: XCTestCase {
    func testSelectionSurfaceTracksLiveTextSizeWidthAndSelectionChanges() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let controller = UIViewController()
        window.rootViewController = controller
        let control = PortfolioLensControl()
        control.setTitle("Tokens", forSegmentAt: 0)
        control.setTitle("Networks", forSegmentAt: 1)
        controller.view.addSubview(control)
        control.snp.makeConstraints { make in
            make.top.equalTo(controller.view.safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
        }
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        let thumb = try XCTUnwrap(control.subviews.compactMap { $0 as? FWNeuView }.first { $0.style == .raised1 })
        let scenarios: [(UIContentSizeCategory, CGFloat)] = [
            (.large, 320), (.accessibilityExtraExtraExtraLarge, 320), (.large, 640), (.large, 320)
        ]
        for (category, width) in scenarios {
            control.selectedSegmentIndex = 1 - control.selectedSegmentIndex
            if #available(iOS 17.0, *) {
                window.traitOverrides.preferredContentSizeCategory = category
            }
            window.frame.size.width = width
            window.layoutIfNeeded()
            try await Task.sleep(nanoseconds: 20_000_000)
            window.layoutIfNeeded()
            let button = control.segmentButtons[control.selectedSegmentIndex]
            let expected = button.convert(button.bounds, to: control)
            XCTAssertGreaterThan(expected.width, 44)
            XCTAssertEqual(thumb.frame.minX, expected.minX, accuracy: 0.5)
            XCTAssertEqual(thumb.frame.minY, expected.minY, accuracy: 0.5)
            XCTAssertEqual(thumb.frame.width, expected.width, accuracy: 0.5)
            XCTAssertEqual(thumb.frame.height, expected.height, accuracy: 0.5)
            XCTAssertTrue(control.bounds.contains(thumb.frame))
        }
    }
}

@MainActor
final class SheetRimMotionBoundaryTests: XCTestCase {
    func testEverySheetRimStaysStillAcrossAttachmentAndResize() throws {
        let sheet = UIView(frame: CGRect(x: 0, y: 0, width: 320, height: 400))
        FWSheetRim.attach(to: sheet)
        let rim = try XCTUnwrap(sheet.layer.sublayers?.first { $0.name == "fw.sheetRim" })
        XCTAssertEqual(rim.opacity, 1)
        XCTAssertTrue(rim.animationKeys()?.isEmpty ?? true)
        XCTAssertTrue(sheet.bounds.contains(rim.frame))
        rim.add(CABasicAnimation(keyPath: "opacity"), forKey: "stale")
        sheet.frame.size.width = 640
        FWSheetRim.attach(to: sheet)
        FWSheetRim.layout(in: sheet)
        XCTAssertEqual(sheet.layer.sublayers?.filter { $0.name == "fw.sheetRim" }.count, 1)
        XCTAssertEqual(rim.opacity, 1)
        XCTAssertTrue(rim.animationKeys()?.isEmpty ?? true)
        XCTAssertTrue(sheet.bounds.contains(rim.frame))
        XCTAssertGreaterThan(rim.frame.width, 320)
    }
}
