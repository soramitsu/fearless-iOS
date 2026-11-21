import XCTest
import SSFModels
@testable import fearless

final class CovCPJRouterHostController: UIViewController, ControllerBackedProtocol {}

final class CovCPJPoolRoutersTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        window?.rootViewController?.dismiss(animated: false)
        window?.isHidden = true
        window = nil
        super.tearDown()
    }

    private func host(_ controller: UIViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        self.window = window
    }

    /// Hosts a root controller that modally presents a navigation stack with the flow screen on top.
    private func presentFlow() -> (host: CovCPJRouterHostController, screen: CovCPJRouterHostController) {
        let hostController = CovCPJRouterHostController()
        let screen = CovCPJRouterHostController()
        host(hostController)
        hostController.present(UINavigationController(rootViewController: screen), animated: false)
        return (hostController, screen)
    }

    func testChoosePoolRouterPresentsSortPicker() throws {
        let controller = CovCPJRouterHostController()
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
        let first = CovCPJRouterHostController()
        let second = CovCPJRouterHostController()
        let navigation = UINavigationController(rootViewController: first)
        navigation.pushViewController(second, animated: false)
        host(navigation)

        StakingPoolJoinConfigRouter().dismiss(view: second)
        CovCPJFixtures.spin { navigation.viewControllers.count == 1 }

        XCTAssertEqual(navigation.viewControllers.count, 1)
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
        let controller = CovCPJRouterHostController()
        let navigation = UINavigationController(rootViewController: controller)
        host(navigation)

        PoolRolesConfirmRouter().complete(on: controller, title: "Done")

        XCTAssertNil(navigation.presentedViewController)
        XCTAssertNil(controller.presentedViewController)
    }

    func testJoinConfirmRouterFinishDismissesFlow() {
        let flow = presentFlow()

        StakingPoolJoinConfirmRouter().finish(view: flow.screen)
        CovCPJFixtures.spin { flow.host.presentedViewController == nil }

        XCTAssertNil(flow.host.presentedViewController)
    }

    func testJoinConfirmRouterCompleteClosesFlow() {
        let flow = presentFlow()
        let navigation = flow.host.presentedViewController

        StakingPoolJoinConfirmRouter().complete(on: flow.screen, title: "Submitted")
        CovCPJFixtures.spin { flow.host.presentedViewController !== navigation }

        XCTAssertFalse(flow.host.presentedViewController is UINavigationController)
    }

    func testCreateConfirmRouterFinishDismissesFlow() {
        let flow = presentFlow()

        StakingPoolCreateConfirmRouter().finish(view: flow.screen)
        CovCPJFixtures.spin { flow.host.presentedViewController == nil }

        XCTAssertNil(flow.host.presentedViewController)
    }
}
