import UIKit

class WarningAlertPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    enum Constants {
        static let fadeDuration: TimeInterval = 0.1
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toViewController = transitionContext.viewController(forKey: .to),
              let fromViewController = transitionContext.viewController(forKey: .from) else { return }

        let containerView = transitionContext.containerView
        let screenBounds = UIScreen.main.bounds

        let dimBackgroundView = UIView(frame: screenBounds)
        dimBackgroundView.backgroundColor = .black.withAlphaComponent(0.2)
        dimBackgroundView.alpha = 0.0

        containerView.addSubview(dimBackgroundView)
        var beginFrame = screenBounds
        beginFrame.origin.y = screenBounds.size.height
        containerView.frame = beginFrame

        containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)

        containerView.addConstraint(NSLayoutConstraint(
            item: toViewController.view as Any,
            attribute: .centerX,
            relatedBy: .equal,
            toItem: containerView,
            attribute: .centerX,
            multiplier: 1,
            constant: 0
        ))

        containerView.addConstraint(NSLayoutConstraint(
            item: toViewController.view as Any,
            attribute: .bottom,
            relatedBy: .equal,
            toItem: containerView,
            attribute: .bottom,
            multiplier: 1,
            constant: 0
        ))

        containerView.addConstraint(NSLayoutConstraint(
            item: toViewController.view as Any,
            attribute: .width,
            relatedBy: .equal,
            toItem: containerView,
            attribute: .width,
            multiplier: 1,
            constant: 0
        ))

        UIView.animate(withDuration: Constants.fadeDuration, delay: transitionDuration(using: transitionContext) - Constants.fadeDuration, options: .curveLinear) {
            dimBackgroundView.alpha = 1
        } completion: { _ in
        }

        UIView.animate(withDuration: transitionDuration(using: transitionContext)) {
            containerView.frame = screenBounds
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
