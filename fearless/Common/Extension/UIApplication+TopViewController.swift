import UIKit

extension UIApplication {
    class func topViewController(controller: UIViewController? = SceneWindowFinder.activeWindow()?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topViewController(controller: navigationController.visibleViewController)
        }
        // Ask the main tab bar by destination, which works in both of its tab modes.
        if let mainTabBar = controller as? MainTabBarViewController,
           let selected = mainTabBar.selectedDestination.flatMap({ mainTabBar.controller(for: $0) }) {
            return topViewController(controller: selected)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topViewController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topViewController(controller: presented)
        }
        return controller
    }
}
