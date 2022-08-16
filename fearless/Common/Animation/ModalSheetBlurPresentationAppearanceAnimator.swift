import Foundation
import SoraUI
import UIKit
import SnapKit

// swiftlint:disable type_name
public final class ModalSheetBlurPresentationAppearanceAnimator: NSObject {
    static let UITransitionViewFearlessTag = 130_130
    static let UIVisualEffectViewFearlessTag = 013_013

    private let animator: BlockViewAnimatorProtocol

    public init(animator: BlockViewAnimatorProtocol) {
        self.animator = animator

        super.init()
    }
}

extension ModalSheetBlurPresentationAppearanceAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        animator.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toViewController = transitionContext.viewController(forKey: .to),
            let fromViewController = transitionContext.viewController(forKey: .from)
        else {
            return
        }

        let screenBounds = UIScreen.main.bounds
        let containerView = transitionContext.containerView

        var beginFrame = screenBounds
        beginFrame.origin.y = screenBounds.size.height
        toViewController.view.frame = beginFrame
        containerView.frame = screenBounds

        containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)
        toViewController.view.snp.makeConstraints { make in
            make.top.greaterThanOrEqualTo(containerView.safeAreaLayoutGuide.snp.top)
            make.bottom.equalTo(containerView.snp.bottom)
            make.width.equalTo(containerView.snp.width)
        }
        toViewController.view.layoutIfNeeded()

        let animationBlock: () -> Void = {
            toViewController.view.frame = screenBounds
        }

        let completionBlock: (Bool) -> Void = { finished in
            containerView.tag = Self.UITransitionViewFearlessTag
            transitionContext.completeTransition(finished)
        }

        animator.animate(block: animationBlock, completionBlock: completionBlock)
        UIView.animate(withDuration: 0.1, delay: 0.15) {
            if
                let window = UIApplication.shared.keyWindow,
                let transitionView = window.subviews.first(where: { $0.tag == Self.UITransitionViewFearlessTag }),
                let blurView = transitionView.subviews.first(where: { $0.tag == Self.UIVisualEffectViewFearlessTag }) {
                blurView.alpha = 0
            }
        }
    }
}
