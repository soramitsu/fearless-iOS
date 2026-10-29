import UIKit

class WarningAlertPresentAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    enum Constants {
        static let fadeDuration: TimeInterval = 0.1
    }

    private let layout: AdaptiveSheetLayout

    init(layout: AdaptiveSheetLayout = AdaptiveSheetLayout()) {
        self.layout = layout
        super.init()
    }

    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        0.5
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let target = transitionContext.viewController(forKey: .to)?.view else { return }
        let container = transitionContext.containerView
        let background = UIView(frame: container.bounds)
        background.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        background.backgroundColor = .black.withAlphaComponent(0.2)
        background.alpha = 0
        container.addSubview(background)
        container.addSubview(target)
        layout.apply(to: target, in: container)
        container.layoutIfNeeded()
        target.transform = CGAffineTransform(translationX: 0, y: container.bounds.height)
        let duration = transitionDuration(using: transitionContext)
        UIView.animate(
            withDuration: Constants.fadeDuration,
            delay: duration - Constants.fadeDuration,
            options: .curveLinear
        ) {
            background.alpha = 1
        }
        UIView.animate(withDuration: duration) {
            target.transform = .identity
        } completion: { _ in
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}
