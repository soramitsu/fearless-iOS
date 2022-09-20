import Foundation
import SoraUI

public final class ModalSheetBlurPresentationDismissAnimator: NSObject {
    let animator: BlockViewAnimatorProtocol
    let finalPositionOffset: CGFloat

    public init(animator: BlockViewAnimatorProtocol, finalPositionOffset: CGFloat) {
        self.animator = animator
        self.finalPositionOffset = finalPositionOffset

        super.init()
    }
}

extension ModalSheetBlurPresentationDismissAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        animator.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .from) else {
            return
        }

        let initialFrame = presentedController.view.frame
        var finalFrame = initialFrame
        finalFrame.origin.y = transitionContext.containerView.frame.maxY + finalPositionOffset

        let animationBlock: () -> Void = {
            presentedController.view.frame = finalFrame
        }

        let completionBlock: (Bool) -> Void = { _ in
            if !transitionContext.transitionWasCancelled {
                presentedController.view.removeFromSuperview()
            }

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animator.animate(block: animationBlock, completionBlock: completionBlock)
    }
}
