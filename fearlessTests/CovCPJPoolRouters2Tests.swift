import XCTest
import SSFModels
@testable import fearless

final class CovCPJRouter2HostController: UIViewController, ControllerBackedProtocol {}

/// Router presentations hosted in a window attached to the app's live scene, so UIKit performs real
/// modal transitions (a scene-less window may refuse them).
final class CovCPJPoolRouters2Tests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.rootViewController?.dismiss(animated: false)
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        super.tearDown()
    }

    private func host(_ controller: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        let window = scene.map { UIWindow(windowScene: $0) } ?? UIWindow(frame: .zero)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        self.window = window
    }

    private func presentFlow() -> (host: CovCPJRouter2HostController, screen: CovCPJRouter2HostController) {
        let hostController = CovCPJRouter2HostController()
        let screen = CovCPJRouter2HostController()
        host(hostController)
        hostController.present(UINavigationController(rootViewController: screen), animated: false)
        return (hostController, screen)
    }

    func testChoosePoolRouterPresentsSortPicker() {
        let controller = CovCPJRouter2HostController()
        host(controller)
        let options = TitleSwitchTableViewCellModelFactory().createSortings(
            options: [.totalStake(assetSymbol: "DOT"), .numberOfMembers],
            selectedOption: .numberOfMembers,
            locale: CovCPJFixtures.locale
        )

        StakingPoolJoinChoosePoolRouter().presentOptions(options: options, callback: nil, from: controller)

        XCTAssertNotNil(controller.presentedViewController)
        XCTAssertEqual(controller.presentedViewController?.modalPresentationStyle, .custom)
    }

    func testJoinConfigRouterPopsScreen() {
        let first = CovCPJRouter2HostController()
        let second = CovCPJRouter2HostController()
        let navigation = UINavigationController(rootViewController: first)
        navigation.pushViewController(second, animated: false)
        host(navigation)

        StakingPoolJoinConfigRouter().dismiss(view: second)
        CovCPJFixtures.spin { navigation.viewControllers.count == 1 }

        XCTAssertTrue(navigation.topViewController === first)
    }

    func testPoolRolesRouterFinishDismissesFlow() {
        let flow = presentFlow()
        XCTAssertTrue(flow.host.presentedViewController is UINavigationController)

        PoolRolesConfirmRouter().finish(view: flow.screen)
        CovCPJFixtures.spin { flow.host.presentedViewController == nil }

        XCTAssertNil(flow.host.presentedViewController)
    }

    func testPoolRolesRouterCompleteWithoutModalFlowPresentsNothing() {
        let controller = CovCPJRouter2HostController()
        let navigation = UINavigationController(rootViewController: controller)
        host(navigation)

        PoolRolesConfirmRouter().complete(on: controller, title: "Done")

        XCTAssertNil(navigation.presentedViewController)
    }

    func testJoinConfirmRouterFinishDismissesFlow() {
        let flow = presentFlow()

        StakingPoolJoinConfirmRouter().finish(view: flow.screen)
        CovCPJFixtures.spin { flow.host.presentedViewController == nil }

        XCTAssertNil(flow.host.presentedViewController)
    }

    func testJoinConfirmRouterCompleteClosesFlow() {
        let flow = presentFlow()
        XCTAssertTrue(flow.host.presentedViewController is UINavigationController)

        StakingPoolJoinConfirmRouter().complete(on: flow.screen, title: "Submitted")
        CovCPJFixtures.spin { !(flow.host.presentedViewController is UINavigationController) }

        XCTAssertFalse(flow.host.presentedViewController is UINavigationController)
    }

    func testCreateConfirmRouterFinishDismissesFlow() {
        let flow = presentFlow()

        StakingPoolCreateConfirmRouter().finish(view: flow.screen)
        CovCPJFixtures.spin { flow.host.presentedViewController == nil }

        XCTAssertNil(flow.host.presentedViewController)
    }
}
