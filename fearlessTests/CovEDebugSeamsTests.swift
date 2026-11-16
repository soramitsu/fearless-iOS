@testable import fearless
import SoraUI
import UIKit
import XCTest

/// The DEBUG walk-through seams act on the app's main window. Unit-test launches skip the app's own window
/// (`-UNITTEST`), so each test hosts a `FearlessWindow` that `SceneWindowFinder.mainWindow()` picks.
@MainActor
final class CovEDebugSeamsTests: XCTestCase {
    func testLoaderSeamsCoverTheTopScreenThenLeaveAndTheFillReachesTheEnd() throws {
        let (window, root) = try hostMainWindow()
        defer { close(window, root) }

        FWShikibanDebugSeams.handle("loader")
        FWShikibanDebugSeams.handle("loaderfill")
        let loaders = root.view.subviews.compactMap { $0 as? LoadingView }
        XCTAssertEqual(loaders.count, 2)
        XCTAssertTrue(loaders.allSatisfy { $0.frame == root.view.bounds })
        let mirror = try XCTUnwrap(loaders.last?.subviews.compactMap { $0 as? FWMirrorLoaderView }.first)
        XCTAssertTrue(CovEHost.spin(until: { mirror.progress == 1 }, timeout: 20), "the fill counts up to a full loader")
        XCTAssertTrue(
            CovEHost.spin(until: { !root.view.subviews.contains { $0 is LoadingView } }, timeout: 20),
            "both loaders leave after five seconds"
        )
    }

    func testSealSeamsDrawTheSealThenPresentSuccessOrBreakIt() throws {
        let (window, root) = try hostMainWindow()
        defer { close(window, root) }

        FWShikibanDebugSeams.handle("seal")
        let loader = try XCTUnwrap(root.view.subviews.compactMap { $0 as? LoadingView }.first)
        XCTAssertEqual(loader.accessibilityIdentifier, LoadableViewProtocolConstants.activityIndicatorIdentifier)
        XCTAssertNotNil(FWTransferSeal.sealView(in: root.view), "the seal takes the loader's place")
        XCTAssertTrue(CovEHost.spin(until: { root.presentedViewController is AllDoneViewController }, timeout: 20))
        XCTAssertTrue(CovEHost.spin(until: { !root.view.subviews.contains { $0 is LoadingView } }, timeout: 10))
        dismissAll(root)

        FWShikibanDebugSeams.handle("sealfail")
        XCTAssertNotNil(FWTransferSeal.sealView(in: root.view))
        XCTAssertTrue(CovEHost.spin(until: { !root.view.subviews.contains { $0 is LoadingView } }, timeout: 20))
        XCTAssertTrue(
            CovEHost.spin(until: { FWTransferSeal.sealView(in: root.view) == nil }, timeout: 20),
            "a broken seal falls apart and leaves"
        )
        XCTAssertNil(root.presentedViewController, "a failure shows no success screen")
    }

    func testSealFlowSeamsReplayEachConfirmScreenAndItsRouterOutcome() throws {
        let (window, root) = try hostMainWindow()
        defer { close(window, root) }

        for (flow, screenType) in [
            ("swap", PolkaswapSwapConfirmationViewController.self),
            ("crosschain", CrossChainConfirmationViewController.self),
            ("staking", StakingRebondConfirmationViewController.self)
        ] as [(String, UIViewController.Type)] {
            for fails in [false, true] {
                let name = "sealflow.\(flow)" + (fails ? "fail" : "")
                FWShikibanDebugSeams.handle(name)
                let navigation = try XCTUnwrap(root.presentedViewController as? UINavigationController, name)
                let screen = try XCTUnwrap(navigation.viewControllers.first, name)
                XCTAssertTrue(type(of: screen) == screenType, name)
                XCTAssertEqual(navigation.modalPresentationStyle, .fullScreen)

                let outcome: () -> Bool
                switch (flow, fails) {
                case (_, true):
                    outcome = { screen.presentedViewController != nil }
                case ("swap", false):
                    outcome = { screen.presentedViewController is AllDoneViewController }
                case ("crosschain", false):
                    outcome = { root.presentedViewController is AllDoneViewController }
                default:
                    outcome = { root.presentedViewController == nil }
                }
                XCTAssertTrue(CovEHost.spin(until: outcome, timeout: 25), "\(name) reaches its router outcome")
                dismissAll(root)
            }
        }
    }

    func testFeelSeamsAnnounceASyntheticArrivalAndShowTheSendSuccessScreen() throws {
        let (window, root) = try hostMainWindow()
        defer { close(window, root) }
        var symbols: [String] = []
        let observer = NotificationCenter.default.addObserver(
            forName: FWArrivalAnnouncer.didAnnounce, object: nil, queue: .main
        ) { note in symbols.append(note.userInfo?["symbol"] as? String ?? "?") }
        defer { NotificationCenter.default.removeObserver(observer) }

        let canAnnounce = UIApplication.shared.applicationState == .active && !FWLaunchIgnite.isShowing
        FWFeelDebugSeams.handle(FWFeelDebugSeams.arrival)
        XCTAssertEqual(symbols, canAnnounce ? ["DOT"] : [], "a known 1.0 growing to 2.5 is an arrival")
        FWFeelDebugSeams.handle("jp.co.soramitsu.fearless.debug.unknown")
        XCTAssertNil(root.presentedViewController)

        FWFeelDebugSeams.install()
        FWFeelDebugSeams.install()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(FWFeelDebugSeams.sendSuccess as CFString), nil, nil, true
        )
        XCTAssertTrue(
            CovEHost.spin(until: { root.presentedViewController is AllDoneViewController }, timeout: 10),
            "the installed seam answers the Darwin notification with the send success screen"
        )

        let recorder = CovEFeedbackRecorder()
        let announcer = FWArrivalAnnouncer(feedback: recorder, canAnnounce: { true }, clock: { 100 }, presentBanner: { _ in })
        DispatchQueue.global().async { announcer.announce(symbol: "KSM", locale: Locale(identifier: "en")) }
        XCTAssertTrue(CovEHost.spin(until: { symbols.last == "KSM" }), "announcing off the main queue hops back to it")
        XCTAssertEqual(recorder.patterns, [.receive])
    }

    private func hostMainWindow() throws -> (UIWindow, UIViewController) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = FearlessWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: CovEHost.phoneSize)
        let root = UIViewController()
        root.view.backgroundColor = .black
        window.rootViewController = root
        window.isHidden = false
        root.view.layoutIfNeeded()
        XCTAssertTrue(SceneWindowFinder.mainWindow() === window, "the seams act on the hosted window")
        return (window, root)
    }

    private func dismissAll(_ root: UIViewController) {
        guard root.presentedViewController != nil else { return }
        root.dismiss(animated: false)
        CovEHost.spin(until: { root.presentedViewController == nil }, timeout: 5)
    }

    private func close(_ window: UIWindow, _ root: UIViewController) {
        dismissAll(root)
        root.view.subviews.forEach { $0.removeFromSuperview() }
        CovEHost.close(window)
    }
}
