import Foundation
import SoraFoundation
import UIKit
import XCTest

@testable import fearless

final class CovDTabFactoryActionsTests: XCTestCase {
    private var window: UIWindow?

    override func tearDown() {
        CovDFixtures.tearDown(window)
        window = nil
        super.tearDown()
    }

    private func button(_ identifier: String, in view: UIView) -> UIButton? {
        CovDFixtures.allButtons(in: view).first { $0.accessibilityIdentifier == identifier }
    }

    func testUnavailableSwapTabOffersNetworkAndWalletChoices() throws {
        let navigation = try XCTUnwrap(
            MainTabBarViewFactory.createPolkaswapController(wallet: CovDFixtures.wallet(substrate: false)) as? UINavigationController
        )
        XCTAssertEqual(navigation.tabBarItem.title, MainTabBarDestination.polkaswap.title)
        XCTAssertNil(navigation.tabBarItem.image)
        let unavailable = try XCTUnwrap(navigation.viewControllers.first as? FeatureUnavailableViewController)
        window = try CovDFixtures.host(navigation)
        unavailable.view.layoutIfNeeded()

        let chooseNetwork = try XCTUnwrap(button("unavailable.action.0", in: unavailable.view))
        XCTAssertEqual(chooseNetwork.accessibilityLabel, "Choose network")
        chooseNetwork.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovDFixtures.spin { unavailable.presentedViewController != nil })
        unavailable.presentedViewController?.dismiss(animated: false)
        XCTAssertTrue(CovDFixtures.spin { unavailable.presentedViewController == nil })

        let manageWallets = try XCTUnwrap(button("unavailable.action.1", in: unavailable.view))
        XCTAssertEqual(manageWallets.accessibilityLabel, "Manage wallets")
        manageWallets.sendActions(for: .touchUpInside)
        XCTAssertTrue(CovDFixtures.spin { unavailable.presentedViewController != nil })
    }

    func testTabItemsUseTintedIconsExceptForTheRaisedSwapButton() {
        for destination in MainTabBarDestination.allCases {
            let item = MainTabBarViewFactory.createTabBarItem(for: destination)
            XCTAssertEqual(item.title, destination.title)
            XCTAssertEqual(item.accessibilityLabel, destination.title)
            XCTAssertEqual(item.image == nil, destination == .polkaswap, "\(destination)")
            XCTAssertEqual(item.selectedImage == nil, destination == .polkaswap, "\(destination)")
        }
    }

    private func destinations(pushingOnto destination: MainTabBarDestination) -> ([UIViewController], UINavigationController) {
        let controllers = MainTabBarDestination.allCases.map { _ in UINavigationController(rootViewController: UIViewController()) }
        return (controllers, controllers[destination.rawValue])
    }

    func testTabBarDeclaresItsFlightTierAndKeepsTheMiddleButtonInSync() throws {
        let (controllers, _) = destinations(pushingOnto: .portfolio)
        let controller = MainTabBarViewController(
            viewControllers: controllers, presenter: CovDTabPresenterSpy(), localizationManager: LocalizationManager.shared, idiom: .phone
        )
        window = try CovDFixtures.host(controller)
        XCTAssertEqual(controller.flightTiers.count, 1)
        XCTAssertTrue(controller.flightTiers.first?.view === controller.tabBar)
        XCTAssertEqual(controller.flightTiers.first?.tier, 2)
        controller.selectedIndex = MainTabBarDestination.defi.rawValue
        controller.tabBarController(controller, didSelect: controllers[MainTabBarDestination.defi.rawValue])
        XCTAssertEqual(controller.selectedDestination, .defi)
        XCTAssertTrue(controller.tabBarController(controller, shouldSelect: controllers[MainTabBarDestination.settings.rawValue]))
    }

    func testMiddleButtonDimsWhilePressed() throws {
        let button = TabBarMiddleButton(frame: CGRect(x: 0, y: 0, width: 56, height: 56))
        let gradient = try XCTUnwrap(button.layer.sublayers?.compactMap { $0 as? CAGradientLayer }.first)
        XCTAssertEqual(gradient.opacity, 1)
        button.isHighlighted = true
        XCTAssertEqual(gradient.opacity, 0.86, accuracy: 0.001)
        button.isHighlighted = true
        XCTAssertEqual(gradient.opacity, 0.86, accuracy: 0.001)
        button.isHighlighted = false
        XCTAssertEqual(gradient.opacity, 1)
    }

    func testAdaptiveTabsReturnToRootWhenTheSelectedTabIsChosenAgain() throws {
        guard #available(iOS 18.0, *) else { return }
        let (controllers, portfolio) = destinations(pushingOnto: .portfolio)
        let controller = MainTabBarViewController(
            viewControllers: controllers, presenter: CovDTabPresenterSpy(), localizationManager: LocalizationManager.shared, idiom: .pad
        )
        XCTAssertTrue(controller.usesAdaptiveTabs)
        window = try CovDFixtures.host(controller, size: CGSize(width: 1024, height: 768))
        let selected = try XCTUnwrap(controller.selectedTab)
        XCTAssertEqual(controller.selectedDestination, .portfolio)
        portfolio.pushViewController(UIViewController(), animated: false)
        XCTAssertEqual(portfolio.viewControllers.count, 2)
        XCTAssertTrue(controller.tabBarController(controller, shouldSelectTab: selected))
        XCTAssertTrue(CovDFixtures.spin { portfolio.viewControllers.count == 1 })
    }
}

