import UIKit

extension UIViewController {
    func wrappedFromNavigationController() -> UIViewController? {
        if let navigationController = self as? UINavigationController {
            return navigationController.viewControllers.first
        }

        return self
    }
}
