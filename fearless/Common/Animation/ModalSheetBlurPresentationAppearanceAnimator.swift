import Foundation
import SoraUI
import UIKit
import SnapKit

// swiftlint:disable type_name
final class ModalSheetBlurPresentationAppearanceAnimator: NSObject {
    static let UITransitionViewFearlessTag = 130_130
    static let UIVisualEffectViewFearlessTag = 013_013

    private let animator: BlockViewAnimatorProtocol
    private let layout: (UIView) -> Void

    init(animator: BlockViewAnimatorProtocol, layout: @escaping (UIView) -> Void) {
        self.animator = animator
        self.layout = layout

        super.init()
    }
}

extension ModalSheetBlurPresentationAppearanceAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        animator.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toViewController = transitionContext.viewController(forKey: .to),
            let fromViewController = transitionContext.viewController(forKey: .from)
        else {
            return
        }

        let containerView = transitionContext.containerView
        containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)
        layout(containerView)
        containerView.layoutIfNeeded()
        toViewController.view.transform = CGAffineTransform(translationX: 0, y: containerView.bounds.height)

        let animationBlock: () -> Void = {
            toViewController.view.transform = .identity
        }

        let completionBlock: (Bool) -> Void = { finished in
            containerView.tag = Self.UITransitionViewFearlessTag
            transitionContext.completeTransition(finished)
        }

        animator.animate(block: animationBlock, completionBlock: completionBlock)
        UIView.animate(withDuration: 0.1, delay: 0.15) {
            if
                let window = SceneWindowFinder.activeWindow(),
                let transitionView = window.subviews.first(where: { $0.tag == Self.UITransitionViewFearlessTag }),
                let blurView = transitionView.subviews.first(where: { $0.tag == Self.UIVisualEffectViewFearlessTag }) {
                blurView.alpha = 0
            }
        }
    }
}
