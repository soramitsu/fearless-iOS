import AVFoundation
import SoraFoundation
import SoraUI
import UIKit
import XCTest
@testable import fearless

final class AdaptiveLayoutTests: XCTestCase {
    private let regularPad = UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceIdiom: .pad),
        UITraitCollection(horizontalSizeClass: .regular)
    ])
    private let compactPad = UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceIdiom: .pad),
        UITraitCollection(horizontalSizeClass: .compact)
    ])
    private let regularPhone = UITraitCollection(traitsFrom: [
        UITraitCollection(userInterfaceIdiom: .phone),
        UITraitCollection(horizontalSizeClass: .regular)
    ])

    func testColumnInsetCentersTheColumnOnlyWhenTheContainerIsWider() {
        XCTAssertEqual(AdaptiveLayout.columnInset(containerWidth: 1194), 237)
        XCTAssertEqual(AdaptiveLayout.columnInset(containerWidth: 1195), 237)
        XCTAssertEqual(AdaptiveLayout.columnInset(containerWidth: 720), 0)
        XCTAssertEqual(AdaptiveLayout.columnInset(containerWidth: 375), 0)
        XCTAssertEqual(AdaptiveLayout.columnInset(containerWidth: 1366, maxWidth: 560), 403)
    }

    func testSheetCardKeepsItsMarginsInNarrowWindows() {
        XCTAssertEqual(AdaptiveLayout.sheetCardWidth(containerWidth: 1194), AdaptiveLayout.sheetWidth)
        XCTAssertEqual(AdaptiveLayout.sheetCardWidth(containerWidth: 500), 452)
        XCTAssertEqual(AdaptiveLayout.sheetCardWidth(containerWidth: 10), 0)
    }

    func testRegularWidthMeansAnIPadWithRegularHorizontalSizeClass() {
        XCTAssertTrue(AdaptiveLayout.isRegularWidth(regularPad))
        XCTAssertFalse(AdaptiveLayout.isRegularWidth(compactPad))
        XCTAssertFalse(AdaptiveLayout.isRegularWidth(regularPhone))
    }

    func testContentColumnFollowsTheSizeClassAndKeepsVerticalInsets() {
        let screen = UIViewController()
        screen.additionalSafeAreaInsets.bottom = 30

        screen.applyAdaptiveContentColumn(containerWidth: 1194, containerSafeArea: .zero, traits: regularPad)
        XCTAssertEqual(screen.additionalSafeAreaInsets.left, 237)
        XCTAssertEqual(screen.additionalSafeAreaInsets.right, 237)
        XCTAssertEqual(screen.additionalSafeAreaInsets.bottom, 30)

        let sidebarSafeArea = UIEdgeInsets(top: 0, left: 100, bottom: 0, right: 0)
        screen.applyAdaptiveContentColumn(containerWidth: 1194, containerSafeArea: sidebarSafeArea, traits: regularPad)
        XCTAssertEqual(screen.additionalSafeAreaInsets.left, 187)

        screen.applyAdaptiveContentColumn(containerWidth: 1194, containerSafeArea: .zero, traits: compactPad)
        XCTAssertEqual(screen.additionalSafeAreaInsets.left, 0)
        XCTAssertEqual(screen.additionalSafeAreaInsets.right, 0)
        XCTAssertEqual(screen.additionalSafeAreaInsets.bottom, 30)
    }

    func testFullWidthScreensKeepTheWholeContainer() {
        let screen = FullWidthScreen()

        screen.applyAdaptiveContentColumn(containerWidth: 1366, containerSafeArea: .zero, traits: regularPad)

        XCTAssertEqual(screen.additionalSafeAreaInsets, .zero)
    }

    func testShareSheetIsAnchoredInsideThePresentingScreen() {
        let host = UIViewController()
        host.view.frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        let share = UIActivityViewController(activityItems: ["fearless"], applicationActivities: nil)

        host.anchorPopover(of: share)

        let popover = share.popoverPresentationController
        XCTAssertTrue(popover?.sourceView === host.view)
        XCTAssertEqual(popover?.sourceRect, CGRect(x: 400, y: 300, width: 0, height: 0))
        XCTAssertEqual(popover?.permittedArrowDirections, [])
    }

    func testExistingSourceViewAnchorIsKept() {
        let host = UIViewController()
        host.loadViewIfNeeded()
        let anchor = UIView(frame: CGRect(x: 10, y: 10, width: 44, height: 44))
        host.view.addSubview(anchor)
        let share = UIActivityViewController(activityItems: ["fearless"], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = anchor
        share.popoverPresentationController?.sourceRect = anchor.bounds

        host.anchorPopover(of: share)

        XCTAssertTrue(share.popoverPresentationController?.sourceView === anchor)
        XCTAssertEqual(share.popoverPresentationController?.sourceRect, anchor.bounds)
    }

    func testNonPopoverPresentationsAreLeftAlone() {
        let host = UIViewController()
        host.loadViewIfNeeded()
        let sheet = UIViewController()
        sheet.modalPresentationStyle = .formSheet

        host.anchorPopover(of: sheet)

        XCTAssertNil(sheet.popoverPresentationController)
    }
}

final class ScanQRCameraOrientationTests: XCTestCase {
    func testCameraPreviewFollowsEveryInterfaceOrientation() {
        XCTAssertEqual(ScanQRViewController.videoRotationAngle(for: .portrait), 90)
        XCTAssertEqual(ScanQRViewController.videoRotationAngle(for: .landscapeRight), 0)
        XCTAssertEqual(ScanQRViewController.videoRotationAngle(for: .landscapeLeft), 180)
        XCTAssertEqual(ScanQRViewController.videoRotationAngle(for: .portraitUpsideDown), 270)
        XCTAssertEqual(ScanQRViewController.videoRotationAngle(for: .unknown), 90)
    }

    func testPreIOS17PreviewOrientationMatchesTheInterface() {
        XCTAssertEqual(ScanQRViewController.videoOrientation(for: .portrait), .portrait)
        XCTAssertEqual(ScanQRViewController.videoOrientation(for: .landscapeRight), .landscapeRight)
        XCTAssertEqual(ScanQRViewController.videoOrientation(for: .landscapeLeft), .landscapeLeft)
        XCTAssertEqual(ScanQRViewController.videoOrientation(for: .portraitUpsideDown), .portraitUpsideDown)
    }
}

final class MainTabBarAdaptiveTabsTests: XCTestCase {
    func testIPadUsesSidebarTabsForEveryDestination() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("Sidebar tabs need iOS 18")
        }
        let (tabBar, controllers) = makeTabBar(idiom: .pad)

        XCTAssertTrue(tabBar.usesAdaptiveTabs)
        XCTAssertEqual(tabBar.mode, .tabSidebar)
        XCTAssertEqual(tabBar.tabs.map(\.identifier), MainTabBarDestination.allCases.map(\.tabIdentifier))
        XCTAssertEqual(tabBar.tabs.map(\.title), MainTabBarDestination.allCases.map(\.title))
        for destination in MainTabBarDestination.allCases {
            XCTAssertTrue(tabBar.controller(for: destination) === controllers[destination.rawValue])
        }
    }

    func testIPadSelectionAndReselectionWorkByDestination() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("Sidebar tabs need iOS 18")
        }
        let (tabBar, controllers) = makeTabBar(idiom: .pad)
        tabBar.loadViewIfNeeded()

        tabBar.select(destination: .settings)
        XCTAssertEqual(tabBar.selectedDestination, .settings)

        let swapNavigation = try XCTUnwrap(controllers[MainTabBarDestination.polkaswap.rawValue] as? UINavigationController)
        tabBar.select(destination: .polkaswap)
        swapNavigation.pushViewController(UIViewController(), animated: false)
        tabBar.select(destination: .polkaswap)

        XCTAssertEqual(tabBar.selectedDestination, .polkaswap)
        XCTAssertEqual(swapNavigation.viewControllers.count, 1)
    }

    func testIPadReplacesOneDestinationAndKeepsTheSelection() throws {
        guard #available(iOS 18.0, *) else {
            throw XCTSkip("Sidebar tabs need iOS 18")
        }
        let (tabBar, _) = makeTabBar(idiom: .pad)
        tabBar.loadViewIfNeeded()
        tabBar.select(destination: .crossChain)
        let untouchedTab = tabBar.tab(forIdentifier: MainTabBarDestination.settings.tabIdentifier)

        let replacement = UINavigationController(rootViewController: UIViewController())
        tabBar.didReplaceView(for: replacement, for: MainTabBarDestination.portfolio.rawValue)

        XCTAssertTrue(tabBar.controller(for: .portfolio) === replacement)
        XCTAssertEqual(tabBar.tabs.count, MainTabBarDestination.allCases.count)
        XCTAssertTrue(tabBar.tab(forIdentifier: MainTabBarDestination.settings.tabIdentifier) === untouchedTab)
        XCTAssertEqual(tabBar.selectedDestination, .crossChain)
    }

    func testIPhoneKeepsTheCustomTabBar() {
        let (tabBar, controllers) = makeTabBar(idiom: .phone)
        tabBar.loadViewIfNeeded()

        XCTAssertFalse(tabBar.usesAdaptiveTabs)
        XCTAssertEqual(tabBar.viewControllers?.count, controllers.count)

        tabBar.select(destination: .crossChain)

        XCTAssertEqual(tabBar.selectedIndex, MainTabBarDestination.crossChain.rawValue)
        XCTAssertEqual(tabBar.selectedDestination, .crossChain)
    }

    func testDestinationsRoundTripThroughTabIdentifiers() {
        for destination in MainTabBarDestination.allCases {
            XCTAssertEqual(MainTabBarDestination(tabIdentifier: destination.tabIdentifier), destination)
        }
        XCTAssertNil(MainTabBarDestination(tabIdentifier: "fearless.tab.unknown"))
    }

    private func makeTabBar(idiom: UIUserInterfaceIdiom) -> (MainTabBarViewController, [UIViewController]) {
        let controllers = MainTabBarDestination.allCases.map { _ in
            UINavigationController(rootViewController: UIViewController()) as UIViewController
        }
        let tabBar = MainTabBarViewController(
            viewControllers: controllers,
            presenter: AdaptiveTabsPresenterStub(),
            localizationManager: LocalizationManager.shared,
            idiom: idiom
        )
        return (tabBar, controllers)
    }
}

private final class FullWidthScreen: UIViewController, AdaptiveFullWidthContent {}

private final class AdaptiveTabsPresenterStub: MainTabBarPresenterProtocol {
    func didLoad(view _: MainTabBarViewProtocol) {}
}

final class IPadPickerPresentationTests: XCTestCase {
    func testPickerFactoryKeepsTheExistingIPhonePresentation() {
        XCTAssertTrue(ModalSheetBlurPresentationFactory.forPicker(configuration: .fearless, idiom: .phone)
            is ModalSheetPresentationFactory)
        XCTAssertTrue(ModalSheetBlurPresentationFactory.forPicker(configuration: .fearless, idiom: .pad)
            is ModalSheetBlurPresentationFactory)
    }

    func testPickerCardFollowsRotationAndReturnsToBottomSheetInCompactWidth() {
        let picker = UIViewController()
        picker.preferredContentSize = CGSize(width: 0, height: 300)
        let presentation = ModalSheetBlurPresentationController(
            presentedViewController: picker, presenting: UIViewController(),
            configuration: .fearless, usesPreferredContentSize: true
        )
        let container = PickerLayoutContainer(frame: CGRect(x: 0, y: 0, width: 834, height: 1194))
        presentation.layoutPreferredContent(in: container)
        XCTAssertEqual(picker.view.frame.width, 560)
        XCTAssertEqual(picker.view.frame.height, 300)
        XCTAssertEqual(picker.view.center.x, 417)
        XCTAssertEqual(picker.view.center.y, 599)
        XCTAssertEqual(picker.view.layer.cornerRadius, AdaptiveLayout.sheetCornerRadius)

        container.frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        presentation.layoutPreferredContent(in: container)
        XCTAssertEqual(picker.view.center.x, 597)
        XCTAssertEqual(picker.view.center.y, 419)
        XCTAssertEqual(picker.view.frame.height, 300)

        container.frame = CGRect(x: 0, y: 0, width: 375, height: 834)
        container.horizontalSizeClass = .compact
        presentation.layoutPreferredContent(in: container)
        XCTAssertEqual(picker.view.frame, CGRect(x: 0, y: 514, width: 375, height: 320))
        XCTAssertEqual(picker.view.layer.cornerRadius, 0)

        container.frame = CGRect(x: 0, y: 0, width: 834, height: 1194)
        container.horizontalSizeClass = .regular
        presentation.layoutPreferredContent(in: container)
        XCTAssertEqual(picker.view.frame.width, 560)
        XCTAssertEqual(picker.view.center.x, 417)
    }

    func testLongPickerKeepsItsHeaderAndScrollableTableInsideTheSafeArea() {
        let picker = UIViewController()
        picker.preferredContentSize = CGSize(width: 0, height: 3000)
        let presentation = ModalSheetBlurPresentationController(
            presentedViewController: picker, presenting: UIViewController(),
            configuration: .fearless, usesPreferredContentSize: true
        )
        let container = PickerLayoutContainer(frame: CGRect(x: 0, y: 0, width: 500, height: 700))
        presentation.layoutPreferredContent(in: container)
        XCTAssertEqual(picker.view.frame, CGRect(x: 24, y: 48, width: 452, height: 608))

        picker.preferredContentSize.height = 140
        presentation.layoutPreferredContent(in: container)
        XCTAssertEqual(picker.view.frame.height, 140)
        XCTAssertEqual(picker.view.center.y, 352)
    }

    func testPickerSelectionDismissesThroughAppPresentationAndCallsBackOnce() throws {
        let picker = PickerDismissalSpy()
        var selections: [Int] = []
        picker.selectionCallback = { selections.append($0) }
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearless, usesPreferredContentSize: true)
        let host = UIViewController()
        let presentation = try XCTUnwrap(factory.presentationController(
            forPresented: picker, presenting: host, source: host
        ) as? ModalSheetBlurPresentationController)
        XCTAssertTrue(picker.presenter === presentation)

        picker.tableView(UITableView(), didSelectRowAt: IndexPath(row: 2, section: 0))

        XCTAssertEqual(picker.dismissCount, 1)
        XCTAssertEqual(selections, [2])
        XCTAssertEqual(picker.selectedIndex, 2)
    }

    func testInteractiveDismissalTracksTheActiveTransition() throws {
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearless, usesPreferredContentSize: true)
        let host = UIViewController()
        let picker = UIViewController()
        let presentation = try XCTUnwrap(factory.presentationController(
            forPresented: picker, presenting: host, source: host
        ) as? ModalSheetBlurPresentationController)
        let animator = try XCTUnwrap(factory.animationController(forDismissed: picker))
        XCTAssertNil(factory.interactionControllerForDismissal(using: animator))
        let interaction = UIPercentDrivenInteractiveTransition()
        presentation.interactiveDismissal = interaction
        XCTAssertTrue(factory.interactionControllerForDismissal(using: animator) === interaction)
        presentation.interactiveDismissal = nil
        XCTAssertNil(factory.interactionControllerForDismissal(using: animator))
    }
}

private final class PickerLayoutContainer: UIView {
    var horizontalSizeClass: UIUserInterfaceSizeClass = .regular
    override var traitCollection: UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceIdiom: .pad),
            UITraitCollection(horizontalSizeClass: horizontalSizeClass)
        ])
    }

    override var safeAreaInsets: UIEdgeInsets {
        UIEdgeInsets(top: 24, left: 0, bottom: 20, right: 0)
    }
}

private final class PickerDismissalSpy: ModalPickerViewController<
    TitleWithSubtitleTableViewCell, TitleWithSubtitleViewModel
> {
    var dismissCount = 0
    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissCount += 1
        completion?()
    }
}
