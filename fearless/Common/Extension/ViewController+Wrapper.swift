import UIKit

extension UIViewController {
    func navigationRootViewController() -> UIViewController? {
        if let navigationController = self as? UINavigationController {
            return navigationController.viewControllers.first
        }

        return self
    }
}
