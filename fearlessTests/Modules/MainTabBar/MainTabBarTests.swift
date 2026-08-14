import SoraFoundation
import UIKit
import XCTest

@testable import fearless

final class MainTabBarTests: XCTestCase {
    func testCustomTabBarPreservesItemsAndLayeringAcrossAppearance() {
        let viewControllers = (0 ..< 5).map { index -> UIViewController in
            let viewController = UIViewController()
            viewController.tabBarItem = UITabBarItem(
                title: nil,
                image: UIImage(systemName: "circle"),
                selectedImage: UIImage(systemName: "circle.fill")
            )
            viewController.tabBarItem.tag = index
            return viewController
        }
        let presenter = MainTabBarPresenterSpy()
        let viewController = MainTabBarViewController(
            viewControllers: viewControllers,
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 430, height: 932)
        viewController.selectedIndex = 3
        viewController.view.layoutIfNeeded()

        guard let customTabBar = viewController.tabBar as? TabBar else {
            return XCTFail("The custom tab bar must be installed before its items")
        }

        XCTAssertEqual(customTabBar.items?.map(\.tag), Array(0 ..< 5))
        XCTAssertTrue(customTabBar.items?.allSatisfy { $0.image != nil } == true)

        let installedTabBar = customTabBar
        let selectedItem = customTabBar.selectedItem
        viewController.viewDidAppear(false)

        XCTAssertIdentical(viewController.tabBar, installedTabBar)
        XCTAssertEqual(viewController.tabBar.items?.map(\.tag), Array(0 ..< 5))
        XCTAssertEqual(viewController.selectedIndex, 3)
        XCTAssertIdentical(viewController.tabBar.selectedItem, selectedItem)

        let simulatedSystemItemView = UIView()
        customTabBar.insertSubview(simulatedSystemItemView, at: 0)
        customTabBar.setNeedsLayout()
        customTabBar.layoutIfNeeded()

        guard
            let backgroundIndex = customTabBar.subviews.firstIndex(where: { $0 is UIVisualEffectView }),
            let systemItemIndex = customTabBar.subviews.firstIndex(of: simulatedSystemItemView),
            let middleButtonIndex = customTabBar.subviews.firstIndex(of: customTabBar.middleButton)
        else {
            return XCTFail("Expected tab-bar layers are missing")
        }

        XCTAssertLessThan(backgroundIndex, systemItemIndex)
        XCTAssertEqual(middleButtonIndex, customTabBar.subviews.count - 1)

        customTabBar.middleButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.presentPolkaswapCallCount, 1)
    }

    func testApplicationUsesPreIOS26DesignCompatibility() {
        XCTAssertEqual(
            Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool,
            true
        )
    }
}

private final class MainTabBarPresenterSpy: MainTabBarPresenterProtocol {
    private(set) var presentPolkaswapCallCount = 0

    func didLoad(view _: MainTabBarViewProtocol) {}

    func presentPolkaswap() {
        presentPolkaswapCallCount += 1
    }
}
