import UIKit

protocol RootControllerAnimationCoordinatorProtocol {
    func animateTransition(to controller: UIViewController)
    func animateTransition(to controller: UIViewController, in window: UIWindow)
}

extension RootControllerAnimationCoordinatorProtocol {
    private func findWindow(from controller: UIViewController) -> UIWindow? {
        var window = controller.view.window

        if window == nil {
            if #available(iOS 13.0, *) {
                window = SceneWindowFinder.activeWindow(from: controller.view.window?.windowScene)
            } else {
                window = UIApplication.shared.delegate?.window ?? UIApplication.shared.keyWindow
            }
        }

        return window
    }

    func animateTransition(to controller: UIViewController) {
        guard let window = findWindow(from: controller) else {
            return
        }

        animateTransition(to: controller, in: window)
    }
}

class RootControllerAnimationCoordinator {
    var type = CATransitionType.fade
    var timingFunction = CAMediaTimingFunctionName.easeOut
    var duration = 0.3
    var animationKey = "window.root.transition"
}

extension RootControllerAnimationCoordinator: RootControllerAnimationCoordinatorProtocol {
    func animateTransition(to controller: UIViewController, in window: UIWindow) {
        let animation = CATransition()
        animation.type = type
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: timingFunction)

        window.rootViewController = controller

        window.layer.add(animation, forKey: animationKey)
    }
}
