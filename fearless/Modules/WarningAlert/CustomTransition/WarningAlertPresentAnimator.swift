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
        let screenBounds = containerView.window?.bounds ?? UIScreen.main.bounds

        let dimBackgroundView = UIView(frame: screenBounds)
        dimBackgroundView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dimBackgroundView.backgroundColor = .black.withAlphaComponent(0.2)
        dimBackgroundView.alpha = 0.0

        containerView.addSubview(dimBackgroundView)
        var beginFrame = screenBounds
        beginFrame.origin.y = screenBounds.size.height
        containerView.frame = beginFrame

        containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)

        if AdaptiveLayout.isRegularWidth(containerView.traitCollection) {
            layoutAsCard(toViewController.view, in: containerView)
        } else {
            layoutAsSheet(toViewController.view, in: containerView)
        }

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

    private func layoutAsSheet(_ view: UIView, in containerView: UIView) {
        containerView.addConstraint(NSLayoutConstraint(
            item: view as Any,
            attribute: .centerX,
            relatedBy: .equal,
            toItem: containerView,
            attribute: .centerX,
            multiplier: 1,
            constant: 0
        ))

        containerView.addConstraint(NSLayoutConstraint(
            item: view as Any,
            attribute: .bottom,
            relatedBy: .equal,
            toItem: containerView,
            attribute: .bottom,
            multiplier: 1,
            constant: 0
        ))

        containerView.addConstraint(NSLayoutConstraint(
            item: view as Any,
            attribute: .width,
            relatedBy: .equal,
            toItem: containerView,
            attribute: .width,
            multiplier: 1,
            constant: 0
        ))
    }

    /// A regular-width iPad window shows the alert as a centered card rather than a
    /// bottom sheet stretched across the screen.
    private func layoutAsCard(_ view: UIView, in containerView: UIView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = AdaptiveLayout.sheetCornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true

        let guide = containerView.safeAreaLayoutGuide
        let centerY = view.centerYAnchor.constraint(equalTo: guide.centerYAnchor)
        centerY.priority = .defaultHigh
        let width = view.widthAnchor.constraint(equalToConstant: AdaptiveLayout.sheetWidth)
        width.priority = .defaultHigh
        NSLayoutConstraint.activate([
            view.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            centerY,
            width,
            view.widthAnchor.constraint(
                lessThanOrEqualTo: guide.widthAnchor,
                constant: -2 * AdaptiveLayout.sheetMargin
            ),
            view.topAnchor.constraint(greaterThanOrEqualTo: guide.topAnchor, constant: AdaptiveLayout.sheetMargin),
            view.bottomAnchor.constraint(lessThanOrEqualTo: guide.bottomAnchor, constant: -AdaptiveLayout.sheetMargin)
        ])
    }
}
