import UIKit
import SoraUI

struct MainTransitionHelper {
    static func transitToMainIfExists(tabBarController: UITabBarController?,
                                      selectingIndex: Int = MainTabBarViewFactory.walletIndex,
                                      closing navigationController: UINavigationController,
                                      animated: Bool) {

        if let presentingController = navigationController.presentingViewController {
            presentingController.dismiss(animated: animated, completion: nil)
            return
        }

        if navigationController.presentedViewController != nil {
            navigationController.presentedViewController?.dismiss(animated: true, completion: nil)
        }

        guard let tabBarController = tabBarController else {
            return
        }

        guard tabBarController.selectedIndex != selectingIndex else {
            navigationController.popToRootViewController(animated: animated)
            return
        }

        navigationController.popToRootViewController(animated: false)

        tabBarController.selectedIndex = selectingIndex

        if animated {
            TransitionAnimator(type: .reveal).animate(view: tabBarController.view, completionBlock: nil)
        }
    }
}
