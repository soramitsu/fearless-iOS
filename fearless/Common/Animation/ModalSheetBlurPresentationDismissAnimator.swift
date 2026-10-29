import Foundation
import SoraUI

final class ModalSheetBlurPresentationDismissAnimator: NSObject {
    let animator: BlockViewAnimatorProtocol
    let finalPositionOffset: CGFloat

    init(animator: BlockViewAnimatorProtocol, finalPositionOffset: CGFloat) {
        self.animator = animator
        self.finalPositionOffset = finalPositionOffset

        super.init()
    }
}

extension ModalSheetBlurPresentationDismissAnimator: UIViewControllerAnimatedTransitioning {
    func transitionDuration(using _: UIViewControllerContextTransitioning?) -> TimeInterval {
        animator.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .from) else {
            return
        }

        let initialFrame = presentedController.view.frame
        let initialTransform = presentedController.view.transform
        let distance = transitionContext.containerView.bounds.maxY - initialFrame.minY + finalPositionOffset

        let animationBlock: () -> Void = {
            presentedController.view.transform = CGAffineTransform(translationX: 0, y: distance)
        }

        let completionBlock: (Bool) -> Void = { _ in
            if !transitionContext.transitionWasCancelled {
                presentedController.view.removeFromSuperview()
            } else {
                presentedController.view.transform = initialTransform
            }

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animator.animate(block: animationBlock, completionBlock: completionBlock)
    }
}
