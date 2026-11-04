import UIKit
import SoraUI

struct MainTransitionHelper {
    static func transitToMainTabBarController(
        selectingIndex: Int = MainTabBarDestination.portfolio.rawValue,
        closing controller: UIViewController,
        animated: Bool,
        completionBlock: ((Bool) -> Void)? = nil
    ) {
        if let presentingController = controller.presentingViewController {
            presentingController.dismiss(animated: animated, completion: nil)
        }

        guard let tabBarController = SceneWindowFinder.activeWindow()?.rootViewController as? UITabBarController
        else {
            return
        }

        // The iPad sidebar tabs do not report selectedIndex; ask the tab bar by destination.
        let mainTabBar = tabBarController as? MainTabBarViewController
        let currentIndex = mainTabBar?.selectedDestination?.rawValue ?? tabBarController.selectedIndex
        let selectedController = mainTabBar?.selectedDestination.flatMap { mainTabBar?.controller(for: $0) }
            ?? tabBarController.selectedViewController
        let navigationController = selectedController as? UINavigationController

        guard currentIndex != selectingIndex else {
            navigationController?.popToRootViewController(animated: animated)
            controller.hidesBottomBarWhenPushed = false
            return
        }

        navigationController?.popToRootViewController(animated: false)

        if let mainTabBar = mainTabBar, mainTabBar.usesAdaptiveTabs,
           let destination = MainTabBarDestination(rawValue: selectingIndex) {
            mainTabBar.select(destination: destination)
        } else {
            tabBarController.selectedIndex = selectingIndex
        }

        if animated {
            TransitionAnimator(type: .reveal).animate(view: tabBarController.view, completionBlock: completionBlock)
        }
    }
}
