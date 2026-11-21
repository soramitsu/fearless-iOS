import XCTest
@testable import fearless

final class CovCPMRouterHostView: ControllerBackedProtocol {
    let hostController = UIViewController()
    var isSetup: Bool { true }
    var controller: UIViewController { hostController }
}

final class CovCPMPoolRoutersTests: XCTestCase {
    private var window: UIWindow?
    private var host: CovCPMRouterHostView!

    override func setUp() {
        super.setUp()
        host = CovCPMRouterHostView()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host.hostController
        window.makeKeyAndVisible()
        self.window = window
    }

    override func tearDown() {
        host.hostController.presentedViewController?.dismiss(animated: false)
        window?.isHidden = true
        window = nil
        host = nil
        super.tearDown()
    }

    private func waitForPresentation() -> UIViewController? {
        let deadline = Date().addingTimeInterval(2)
        while host.hostController.presentedViewController == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        return host.hostController.presentedViewController
    }

    func testMainRouterPresentsRewardDetails() {
        let router = StakingPoolMainRouter()

        router.showRewardDetails(from: host, maxReward: ("Max", 0.2), avgReward: ("Avg", 0.1))

        XCTAssertNotNil(waitForPresentation())
    }

    func testManagementRouterPresentsOptionsPicker() {
        let router = StakingPoolManagementRouter()
        var selected: [Int] = []

        router.presentOptions(
            viewModels: [TitleWithSubtitleViewModel(title: "First"), TitleWithSubtitleViewModel(title: "Second")],
            callback: { selected.append($0) },
            from: host
        )

        let presented = waitForPresentation()
        XCTAssertNotNil(presented)
        XCTAssertEqual(presented?.modalPresentationStyle, .custom)
        XCTAssertTrue(selected.isEmpty)
    }

    func testRoutersIgnoreMissingView() {
        StakingPoolMainRouter().showRewardDetails(from: nil, maxReward: ("Max", 1), avgReward: ("Avg", 1))
        StakingPoolManagementRouter().presentOptions(viewModels: [], callback: nil, from: nil)

        XCTAssertNil(host.hostController.presentedViewController)
    }
}
