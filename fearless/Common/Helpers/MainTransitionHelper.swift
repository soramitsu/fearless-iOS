import UIKit
import SoraUI

struct MainTransitionHelper {
    static func transitToMainTabBarController(
        selectingIndex: Int = MainTabBarViewFactory.walletIndex,
        closing controller: UIViewController,
        animated: Bool
    ) {
        if let presentingController = controller.presentingViewController {
            presentingController.dismiss(animated: animated, completion: nil)
        }

        guard let tabBarController = UIApplication.shared
            .delegate?.window??.rootViewController as? UITabBarController
        else {
            return
        }

        let navigationController = tabBarController.selectedViewController as? UINavigationController

        guard tabBarController.selectedIndex != selectingIndex else {
            navigationController?.popToRootViewController(animated: animated)
            return
        }

        navigationController?.popToRootViewController(animated: false)

        tabBarController.selectedIndex = selectingIndex

        if animated {
            TransitionAnimator(type: .reveal).animate(view: tabBarController.view, completionBlock: nil)
        }
    }
}
