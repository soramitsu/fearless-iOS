import SoraFoundation
import UIKit
import XCTest

@testable import fearless

final class MainTabBarTests: XCTestCase {
    private let expectedItemCount = 5

    func testRepeatedAppearancePreservesControllerManagedTabBar() {
        let (viewController, presenter) = makeViewController()

        viewController.loadViewIfNeeded()
        let controllerManagedTabBar = viewController.tabBar

        performAppearanceTransition(on: viewController, appearing: true)
        assertStableTabBar(viewController, expectedTabBar: controllerManagedTabBar)

        performAppearanceTransition(on: viewController, appearing: false)
        performAppearanceTransition(on: viewController, appearing: true)
        viewController.view.layoutIfNeeded()
        viewController.tabBar.layoutIfNeeded()

        assertStableTabBar(viewController, expectedTabBar: controllerManagedTabBar)
        XCTAssertEqual(presenter.didLoadCallCount, 1)

        let middleButton = controls(in: viewController.tabBar)
            .compactMap { $0 as? TabBarMiddleButton }
            .first

        middleButton?.sendActions(for: .touchUpInside)
        XCTAssertEqual(presenter.presentPolkaswapCallCount, 1)

        performAppearanceTransition(on: viewController, appearing: false)
    }

    func testTabBarRendersEveryItemControlInWindow() {
        let (viewController, _) = makeViewController()
        viewController.loadViewIfNeeded()
        let controllerManagedTabBar = viewController.tabBar
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))

        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        viewController.tabBar.layoutIfNeeded()

        assertStableTabBar(viewController, expectedTabBar: controllerManagedTabBar)
        assertRenderedItemControls(viewController, in: window)
    }

    private func makeViewController() -> (MainTabBarViewController, MainTabBarPresenterStub) {
        let viewControllers = (0 ..< expectedItemCount).map { index -> UIViewController in
            let viewController = UIViewController()
            let item = UITabBarItem(
                title: nil,
                image: UIImage(systemName: "circle"),
                tag: index
            )
            item.isEnabled = index != 2
            viewController.tabBarItem = item
            return viewController
        }
        let presenter = MainTabBarPresenterStub()
        let viewController = MainTabBarViewController(
            viewControllers: viewControllers,
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        return (viewController, presenter)
    }

    private func assertStableTabBar(
        _ viewController: MainTabBarViewController,
        expectedTabBar: UITabBar,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(viewController.tabBar === expectedTabBar, file: file, line: line)
        XCTAssertEqual(viewController.tabBar.items?.count, expectedItemCount, file: file, line: line)

        let allControls = controls(in: viewController.tabBar)
        let middleButtons = allControls.compactMap { $0 as? TabBarMiddleButton }

        XCTAssertEqual(middleButtons.count, 1, file: file, line: line)
        XCTAssertEqual(
            viewController.tabBar.subviews.compactMap { $0 as? TabBarBackgroundView }.count,
            1,
            file: file,
            line: line
        )

        if #available(iOS 26.0, *) {
            XCTAssertEqual(viewController.tabBarMinimizeBehavior, .never, file: file, line: line)
        }
    }

    private func assertRenderedItemControls(
        _ viewController: MainTabBarViewController,
        in window: UIWindow,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let allControls = controls(in: viewController.tabBar)
        let middleButtons = allControls.compactMap { $0 as? TabBarMiddleButton }
        let visibleSystemControls = allControls.filter { control in
            !(control is TabBarMiddleButton) &&
                isEffectivelyVisible(control, in: window)
        }
        let controlDescription = visibleSystemControls.map { control in
            let parent = control.superview.map { String(describing: type(of: $0)) } ?? "nil"
            let frame = control.convert(control.bounds, to: viewController.tabBar)
            return "\(String(describing: type(of: control))) " +
                "parent=\(parent) enabled=\(control.isEnabled) frame=\(frame)"
        }.joined(separator: "\n")
        let controlsBySlot = Dictionary(grouping: visibleSystemControls) { control in
            let centerX = control.convert(control.bounds, to: viewController.tabBar).midX
            return Int((centerX * window.screen.scale).rounded())
        }
        let sortedSlots = controlsBySlot.sorted { $0.key < $1.key }

        XCTAssertEqual(middleButtons.count, 1, file: file, line: line)
        XCTAssertTrue(
            middleButtons.first.map { isEffectivelyVisible($0, in: window) } == true,
            file: file,
            line: line
        )
        XCTAssertTrue(viewController.tabBar.subviews.last === middleButtons.first, file: file, line: line)

        XCTAssertEqual(
            sortedSlots.count,
            expectedItemCount,
            "Unexpected rendered tab slots. Controls:\n\(controlDescription)",
            file: file,
            line: line
        )

        for (index, slot) in sortedSlots.enumerated() {
            XCTAssertTrue(
                slot.value.allSatisfy { $0.isEnabled == (index != 2) },
                "Incorrect enabled state for tab slot \(index). Controls:\n\(controlDescription)",
                file: file,
                line: line
            )
        }
    }

    private func performAppearanceTransition(
        on viewController: UIViewController,
        appearing: Bool
    ) {
        viewController.beginAppearanceTransition(appearing, animated: false)
        viewController.endAppearanceTransition()
    }

    private func controls(in view: UIView) -> [UIControl] {
        view.subviews.reduce(into: []) { result, subview in
            if let control = subview as? UIControl {
                result.append(control)
            }

            result.append(contentsOf: controls(in: subview))
        }
    }

    private func isEffectivelyVisible(_ view: UIView, in window: UIWindow) -> Bool {
        guard view.window === window, !view.bounds.isEmpty else {
            return false
        }

        var currentView: UIView? = view

        while let current = currentView {
            guard !current.isHidden, current.alpha > 0.01 else {
                return false
            }

            if current === window {
                return true
            }

            currentView = current.superview
        }

        return false
    }
}

private final class MainTabBarPresenterStub: MainTabBarPresenterProtocol {
    private(set) var didLoadCallCount = 0
    private(set) var presentPolkaswapCallCount = 0

    func didLoad(view _: MainTabBarViewProtocol) {
        didLoadCallCount += 1
    }

    func presentPolkaswap() {
        presentPolkaswapCallCount += 1
    }
}
