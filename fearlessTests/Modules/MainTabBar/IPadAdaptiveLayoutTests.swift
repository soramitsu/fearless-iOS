import AVFoundation
import SoraFoundation
import SoraKeystore
import SoraUI
import SSFModels
import SSFUtils
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

    func testCustomContentUsesUIKitWindowAwareRegionOnIPad() {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 375, height: 625))
        if #available(iOS 26.0, *) {
            view.traitOverrides.userInterfaceIdiom = .pad
            view.updateTraitsIfNeeded()
            XCTAssertTrue(AdaptiveLayout.contentLayoutGuide(in: view) ===
                view.layoutGuide(for: .safeArea(cornerAdaptation: .vertical)))
            XCTAssertEqual(
                AdaptiveLayout.contentInsets(in: view),
                view.edgeInsets(for: .safeArea(cornerAdaptation: .vertical))
            )
            view.traitOverrides.userInterfaceIdiom = .phone
            view.updateTraitsIfNeeded()
        }
        XCTAssertTrue(AdaptiveLayout.contentLayoutGuide(in: view) === view.safeAreaLayoutGuide)
        XCTAssertEqual(AdaptiveLayout.contentInsets(in: view), view.safeAreaInsets)
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

    func testOtherSheetsKeepTheirExistingPullToDismiss() throws {
        let factory = ModalSheetBlurPresentationFactory(configuration: .fearless)
        let host = UIViewController()
        let sheet = UIViewController()
        let presentation = try XCTUnwrap(factory.presentationController(
            forPresented: sheet, presenting: host, source: host
        ) as? ModalSheetBlurPresentationController)
        let animator = try XCTUnwrap(factory.animationController(forDismissed: sheet))
        presentation.interactiveDismissal = UIPercentDrivenInteractiveTransition()
        XCTAssertNil(factory.interactionControllerForDismissal(using: animator))
    }
}

private final class PickerLayoutContainer: UIView {
    var horizontalSizeClass: UIUserInterfaceSizeClass = .regular
    override var traitCollection: UITraitCollection {
        UITraitCollection(traitsFrom: [
            super.traitCollection,
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

final class IPadWorkspaceLayoutTests: XCTestCase {
    func testColumnsRequireUsableWidthAndRespectAccessibleText() {
        let traits = padTraits()
        XCTAssertFalse(AdaptiveLayout.showsColumns(in: 819, traits: traits))
        XCTAssertTrue(AdaptiveLayout.showsColumns(in: 834, traits: traits))
        XCTAssertFalse(AdaptiveLayout.showsColumns(in: 1194, traits: padTraits(category: .accessibilityExtraLarge)))
        XCTAssertFalse(AdaptiveLayout.showsColumns(in: 1194, traits: UITraitCollection(userInterfaceIdiom: .phone)))
    }

    func testSettingsColumnsPreserveDestinationsAndSwitchToOneListOnResize() {
        let presenter = IPadProfilePresenterSpy()
        let controller = ProfileViewController(
            presenter: presenter,
            iconGenerating: UniversalIconGenerator(),
            localizationManager: LocalizationManager.shared
        )
        let host = host(controller, width: 1194, height: 834)
        controller.didReceive(state: .loaded(IPadProfileFixture.model()))
        controller.rootView.layoutIfNeeded()
        let primary = controller.rootView.tableView
        let secondary = controller.rootView.secondaryTableView
        XCTAssertTrue(controller.rootView.usesColumns)
        XCTAssertFalse(secondary.isHidden)
        XCTAssertLessThan(primary.frame.maxX, secondary.frame.minX)
        XCTAssertEqual(controller.numberOfSections(in: primary), 4)
        // Connections, preferences, advanced, about and logout.
        XCTAssertEqual(controller.numberOfSections(in: secondary), 5)
        controller.tableView(primary, didSelectRowAt: IndexPath(row: 0, section: 1))
        controller.tableView(secondary, didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertEqual(presenter.options, [.accountList, .currency])
        controller.tableView(primary, didSelectRowAt: IndexPath(row: 1, section: 0))
        XCTAssertEqual(presenter.accountDetailsCalls, 1)

        resize(controller, in: host, width: 600, height: 834)
        XCTAssertFalse(controller.rootView.usesColumns)
        XCTAssertTrue(secondary.isHidden)
        XCTAssertEqual(controller.numberOfSections(in: primary), 9)
        XCTAssertEqual(controller.numberOfSections(in: secondary), 0)
        controller.tableView(primary, didSelectRowAt: IndexPath(row: 0, section: 5))
        XCTAssertEqual(presenter.options, [.accountList, .currency, .currency])
        resize(controller, in: host, width: 1194, height: 834)
        XCTAssertEqual(controller.numberOfSections(in: primary), 4)
        XCTAssertEqual(controller.numberOfSections(in: secondary), 5)
        // The advanced section keeps its rows in the second column.
        controller.tableView(secondary, didSelectRowAt: IndexPath(row: 0, section: 2))
        XCTAssertEqual(presenter.options.last, .previousData)
    }

    func testIPhoneSettingsKeepOneFullScreenList() {
        let controller = ProfileViewController(
            presenter: IPadProfilePresenterSpy(), iconGenerating: UniversalIconGenerator(),
            localizationManager: LocalizationManager.shared
        )
        let phone = UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceIdiom: .phone), UITraitCollection(horizontalSizeClass: .compact)
        ])
        _ = host(controller, width: 402, height: 874, traits: phone)
        controller.rootView.layoutIfNeeded()
        XCTAssertFalse(controller.rootView.usesColumns)
        XCTAssertTrue(controller.rootView.secondaryTableView.isHidden)
        XCTAssertEqual(controller.rootView.tableView.frame, controller.rootView.bounds)
        XCTAssertEqual(controller.rootView.tableView.contentInsetAdjustmentBehavior, .automatic)
    }

    func testSettingsUseOneReadableColumnForAccessibleText() {
        let controller = ProfileViewController(
            presenter: IPadProfilePresenterSpy(), iconGenerating: UniversalIconGenerator(),
            localizationManager: LocalizationManager.shared
        )
        let host = host(controller, width: 1194, height: 834, traits: padTraits(category: .accessibilityExtraLarge))
        controller.rootView.layoutIfNeeded()
        XCTAssertFalse(controller.rootView.usesColumns)
        XCTAssertEqual(controller.rootView.tableView.frame.width, 720)
        XCTAssertNotNil(host.children.first)
    }

    func testSettingsReflowWhenSidebarChangesSafeAreaWithoutResizing() {
        let controller = ProfileViewController(
            presenter: IPadProfilePresenterSpy(), iconGenerating: UniversalIconGenerator(),
            localizationManager: LocalizationManager.shared
        )
        let parent = host(controller, width: 1194, height: 834)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        XCTAssertNotNil(scene, "Safe-area propagation needs a live window scene")
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: .zero)
        let frame = CGRect(x: 0, y: 0, width: 1194, height: 834)
        window.frame = frame
        window.rootViewController = parent
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }
        window.frame = frame
        parent.view.frame = frame
        controller.view.frame = frame
        parent.view.layoutIfNeeded()
        controller.view.layoutIfNeeded()
        let layout = controller.rootView
        let originalBounds = layout.bounds
        XCTAssertEqual(layout.tableView.frame.minX, 24)
        XCTAssertEqual(layout.tableView.frame.width, 561)

        controller.additionalSafeAreaInsets.left = 280
        layout.safeAreaInsetsDidChange()
        layout.layoutIfNeeded()
        XCTAssertEqual(layout.bounds, originalBounds)
        XCTAssertEqual(layout.safeAreaInsets.left, 280)
        XCTAssertEqual(layout.tableView.frame.minX, 304)
        XCTAssertEqual(layout.tableView.frame.width, 421)
        XCTAssertEqual(layout.secondaryTableView.frame.minX, 749)
        XCTAssertEqual(layout.secondaryTableView.frame.width, 421)

        controller.additionalSafeAreaInsets.left = 0
        layout.safeAreaInsetsDidChange()
        layout.layoutIfNeeded()
        XCTAssertEqual(layout.bounds, originalBounds)
        XCTAssertEqual(layout.safeAreaInsets.left, 0)
        XCTAssertEqual(layout.tableView.frame.minX, 24)
        XCTAssertEqual(layout.tableView.frame.width, 561)
    }

    func testAssetSummaryAndHistoryUseWindowDimensionsAcrossRotationAndResize() {
        let controller = IPadContainerSpy()
        let summary = IPadSummarySpy()
        let detail = IPadDetailSpy()
        controller.content = summary
        controller.draggable = detail
        let host = host(controller, width: 1194, height: 834)
        controller.layoutAdaptivePanels()
        XCTAssertTrue(controller.usesAdaptiveColumns)
        XCTAssertEqual(controller.scrollView.frame.width, 320)
        XCTAssertTrue(detail.view.superview === controller.view)
        XCTAssertGreaterThan(detail.view.frame.width, 600)
        XCTAssertGreaterThan(detail.view.frame.minX, controller.scrollView.frame.maxX)
        XCTAssertTrue(detail.embedded)
        XCTAssertEqual(detail.state, .full)
        XCTAssertTrue(summary.parent === controller)
        XCTAssertTrue(detail.parent === controller)

        resize(controller, in: host, width: 834, height: 1194)
        controller.layoutAdaptivePanels()
        XCTAssertTrue(controller.usesAdaptiveColumns)
        XCTAssertEqual(detail.view.frame.width, 442)
        XCTAssertEqual(detail.view.frame.maxX, 810)
        resize(controller, in: host, width: 500, height: 500)
        controller.layoutAdaptivePanels()
        XCTAssertFalse(controller.usesAdaptiveColumns)
        XCTAssertTrue(detail.view.superview === controller.scrollView)
        XCTAssertEqual(summary.view.frame.width, 500)
        XCTAssertEqual(detail.view.frame.width, 500)
        XCTAssertGreaterThan(detail.view.frame.minY, summary.preferredContentHeight)
        XCTAssertFalse(detail.embedded)
        XCTAssertEqual(detail.state, .compact)
        resize(controller, in: host, width: 375, height: 320, traits: padTraits(sizeClass: .compact))
        controller.layoutAdaptivePanels()
        XCTAssertEqual(detail.view.frame.width, 375)
        XCTAssertGreaterThan(controller.scrollView.contentSize.height, controller.scrollView.bounds.height)
        controller.wantsTransit(to: .full, animating: false)
        XCTAssertEqual(detail.view.frame, CGRect(origin: .zero, size: controller.scrollView.bounds.size))
        controller.wantsTransit(to: .compact, animating: false)
        XCTAssertGreaterThanOrEqual(detail.view.frame.height, 160)
        resize(controller, in: host, width: 1194, height: 834)
        controller.layoutAdaptivePanels()
        XCTAssertTrue(controller.content === summary)
        XCTAssertTrue(controller.draggable === detail)
        XCTAssertEqual(controller.children.count, 2)
    }

    func testIntrinsicSheetReflowsBetweenCardAndBottomSheetWithoutDuplicateConstraints() {
        let container = IPadResizableContainer(frame: CGRect(x: 0, y: 0, width: 834, height: 1194))
        let card = UIView()
        card.layer.cornerRadius = 20
        container.addSubview(card)
        card.heightAnchor.constraint(equalToConstant: 260).isActive = true
        let layout = AdaptiveSheetLayout()
        layout.apply(to: card, in: container)
        container.layoutIfNeeded()
        XCTAssertEqual(card.frame.width, 560)
        XCTAssertEqual(card.center.x, 417)
        XCTAssertEqual(card.center.y, 597)
        let regularConstraintCount = container.constraints.count
        container.bounds.size = CGSize(width: 500, height: 600)
        layout.apply(to: card, in: container)
        container.layoutIfNeeded()
        XCTAssertEqual(card.frame.width, 452)
        container.sizeClass = .compact
        container.bounds.size = CGSize(width: 375, height: 600)
        layout.apply(to: card, in: container)
        container.layoutIfNeeded()
        XCTAssertEqual(card.frame, CGRect(x: 0, y: 340, width: 375, height: 260))
        XCTAssertEqual(card.layer.cornerRadius, 20)
        container.sizeClass = .regular
        container.bounds.size = CGSize(width: 1194, height: 834)
        layout.apply(to: card, in: container)
        container.layoutIfNeeded()
        XCTAssertEqual(card.frame.width, 560)
        XCTAssertEqual(card.center.x, 597)
        XCTAssertEqual(container.constraints.count, regularConstraintCount)
    }

    func testHistorySidePanelRemovesSheetAffordancesAndAllowsScrolling() {
        let layout = WalletTransactionHistoryViewLayout()
        layout.setEmbeddedInColumns(true)
        XCTAssertTrue(layout.closeButton.isHidden)
        XCTAssertTrue(layout.panIndicatorView.isHidden)
        XCTAssertTrue(layout.tableView.isScrollEnabled)
        XCTAssertTrue(layout.tableView.showsVerticalScrollIndicator)
        layout.setEmbeddedInColumns(false)
        XCTAssertFalse(layout.panIndicatorView.isHidden)
    }

    private func padTraits(
        sizeClass: UIUserInterfaceSizeClass = .regular,
        category: UIContentSizeCategory = .large
    ) -> UITraitCollection {
        UITraitCollection(traitsFrom: [
            UITraitCollection(userInterfaceIdiom: .pad), UITraitCollection(horizontalSizeClass: sizeClass),
            UITraitCollection(preferredContentSizeCategory: category)
        ])
    }

    private func host(
        _ child: UIViewController, width: CGFloat, height: CGFloat, traits: UITraitCollection? = nil
    ) -> UIViewController {
        let host = UIViewController()
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        host.addChild(child)
        host.setOverrideTraitCollection(traits ?? padTraits(), forChild: child)
        child.view.frame = host.view.bounds
        host.view.addSubview(child.view)
        child.didMove(toParent: host)
        child.view.setNeedsLayout()
        child.view.layoutIfNeeded()
        return host
    }

    private func resize(
        _ child: UIViewController, in host: UIViewController, width: CGFloat, height: CGFloat,
        traits: UITraitCollection? = nil
    ) {
        host.view.frame.size = CGSize(width: width, height: height)
        host.setOverrideTraitCollection(traits ?? padTraits(), forChild: child)
        child.view.frame = host.view.bounds
        child.view.setNeedsLayout()
        child.view.layoutIfNeeded()
    }
}

private final class IPadProfilePresenterSpy: ProfilePresenterProtocol {
    var options: [ProfileOption] = []
    var accountDetailsCalls = 0
    func didLoad(view _: ProfileViewProtocol) {}
    func activateAccountDetails() {
        accountDetailsCalls += 1
    }

    func activateOption(_ option: ProfileOption) {
        options.append(option)
    }

    func logout() {}
    func switcherValueChanged(isOn _: Bool, index _: Int) {}
    func didTapAccountScore(address _: String?) {}
}

private enum IPadProfileFixture {
    static func model() -> ProfileViewModelProtocol {
        ProfileViewModelFactory(
            iconGenerator: UniversalIconGenerator(),
            biometry: IPadBiometryStub(),
            settings: InMemorySettingsManager(),
            accountScoreFetcher: IPadAccountStatisticsStub()
        ).createProfileViewModel(
            from: AccountGenerator.generateMetaAccount(),
            locale: Locale(identifier: "en"),
            language: Language(code: "en"),
            currency: Currency.defaultCurrency(),
            balance: nil,
            missingAccountIssue: []
        )
    }
}

private struct IPadBiometryStub: BiometryAuthProtocol {
    var availableBiometryType: AvailableBiometryType { .none }

    func authenticate(
        localizedReason _: String,
        completionQueue: DispatchQueue,
        completionBlock: @escaping (Bool) -> Void
    ) {
        completionQueue.async {
            completionBlock(false)
        }
    }
}

private struct IPadAccountStatisticsStub: AccountStatisticsFetching {
    func subscribeForStatistics(
        address _: String
    ) async throws -> AsyncThrowingStream<AccountStatisticsResponse, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func fetchStatistics(address _: String) async throws -> AccountStatisticsResponse? {
        nil
    }
}

private final class IPadContainerSpy: ContainerViewController {
    override var supportsAdaptiveColumns: Bool {
        true
    }
}

private final class IPadSummarySpy: UIViewController, Containable {
    var contentView: UIView {
        view
    }

    var contentInsets: UIEdgeInsets = .zero
    var preferredContentHeight: CGFloat = 300
    var observable = ViewModelObserverContainer<ContainableObserver>()
    func setContentInsets(_ contentInsets: UIEdgeInsets, animated _: Bool) {
        self.contentInsets = contentInsets
    }
}

private final class IPadDetailSpy: UIViewController, Draggable, AdaptiveSidePanel {
    var draggableView: UIView {
        view
    }

    weak var delegate: DraggableDelegate?
    var scrollPanRecognizer: UIPanGestureRecognizer? {
        nil
    }

    var state: DraggableState = .compact
    var embedded = false
    func set(dragableState: DraggableState, animated _: Bool) {
        state = dragableState
    }

    func set(contentInsets _: UIEdgeInsets, for _: DraggableState) {}
    func canDrag(from _: DraggableState) -> Bool {
        true
    }

    func animate(progress _: Double, from _: DraggableState, to _: DraggableState, finalFrame: CGRect) {
        view.frame = finalFrame
    }

    func setEmbeddedInColumns(_ embedded: Bool) {
        self.embedded = embedded
    }
}

private final class IPadResizableContainer: UIView {
    var sizeClass: UIUserInterfaceSizeClass = .regular
    override var traitCollection: UITraitCollection {
        UITraitCollection(traitsFrom: [
            super.traitCollection,
            UITraitCollection(userInterfaceIdiom: .pad), UITraitCollection(horizontalSizeClass: sizeClass)
        ])
    }
}

final class IPadSheetAlertLayoutTests: XCTestCase {
    func testLongMessageScrollsThenReturnsInlineWhenWindowExpands() throws {
        guard #available(iOS 17.0, *) else { return }
        let message = String(repeating: "Long warning. ", count: 35)
        let action = SheetAlertPresentableAction(title: "Continue")
        let view = SheetAlertViewLayout(viewModel: SheetAlertPresentableViewModel(
            title: "Title", message: message, actions: [action], closeAction: "Dismiss"
        ))
        let container = UIView(frame: CGRect(x: 0, y: 0, width: 560, height: 420))
        container.addSubview(view)
        view.traitOverrides.userInterfaceIdiom = .pad
        view.updateTraitsIfNeeded()
        view.frame = container.bounds
        view.layoutIfNeeded()
        let label = try XCTUnwrap(descendants(view).compactMap { $0 as? UILabel }.first { $0.text == message })
        let scroll = try XCTUnwrap(descendants(view).compactMap { $0 as? ScrollableContainerView }.first)
        XCTAssertTrue(label.isDescendant(of: scroll))
        XCTAssertFalse(scroll.isHidden)
        let compactHeight = scroll.constraints.first { $0.firstAttribute == .height && $0.isActive }
        XCTAssertNotNil(compactHeight)
        XCTAssertGreaterThanOrEqual(action.button.frame.height, 44)

        container.frame.size.height = 1400
        view.frame = container.bounds
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertFalse(label.isDescendant(of: scroll))
        XCTAssertTrue(scroll.isHidden)
        XCTAssertFalse(compactHeight?.isActive ?? true)

        container.frame.size.height = 420
        view.frame = container.bounds
        view.setNeedsLayout()
        view.layoutIfNeeded()
        XCTAssertTrue(label.isDescendant(of: scroll))
        XCTAssertFalse(scroll.isHidden)
        XCTAssertEqual(scroll.constraints.filter { $0.firstAttribute == .height && $0.isActive }.count, 1)
    }

    func testScrollingSheetFillsTheSafeAreaAsBottomSheetAndCard() {
        let container = IPadResizableContainer(frame: CGRect(x: 0, y: 0, width: 834, height: 1194))
        let sheet = UIView()
        sheet.layer.cornerRadius = 20
        sheet.layer.cornerCurve = .circular
        container.addSubview(sheet)
        let layout = AdaptiveSheetLayout()
        layout.apply(to: sheet, in: container, fillsHeight: true)
        container.layoutIfNeeded()
        XCTAssertEqual(sheet.frame, CGRect(x: 137, y: 24, width: 560, height: 1146))
        XCTAssertEqual(sheet.layer.cornerRadius, AdaptiveLayout.sheetCornerRadius)
        XCTAssertEqual(sheet.layer.cornerCurve, .continuous)

        container.sizeClass = .compact
        container.bounds.size = CGSize(width: 375, height: 600)
        layout.apply(to: sheet, in: container, fillsHeight: true)
        container.layoutIfNeeded()
        XCTAssertEqual(sheet.frame, CGRect(x: 0, y: 0, width: 375, height: 600))
        XCTAssertEqual(sheet.layer.cornerRadius, 20)
        XCTAssertEqual(sheet.layer.cornerCurve, .circular)
    }

    func testScrollingSheetAlertIsPresentedAtFullHeight() throws {
        let alert = SheetAletViewController(viewModel: SheetAlertPresentableViewModel(
            title: "Warning", message: "Message", actions: [], closeAction: nil, scrollableContent: true
        ))
        let presentation = ModalSheetBlurPresentationController(
            presentedViewController: alert, presenting: UIViewController(), configuration: .fearless
        )
        let container = IPadResizableContainer(frame: CGRect(x: 0, y: 0, width: 1194, height: 834))
        container.addSubview(alert.view)
        presentation.layoutPreferredContent(in: container)
        container.layoutIfNeeded()
        XCTAssertEqual(alert.view.frame, CGRect(x: 317, y: 24, width: 560, height: 786))
    }

    private func descendants(_ view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants($0) }
    }
}
