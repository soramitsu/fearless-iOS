/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

public class ModalSheetPresentationFactory: NSObject {
    let configuration: ModalSheetPresentationConfiguration

    var presentation: ModalSheetPresentationController?

    public init(configuration: ModalSheetPresentationConfiguration) {
        self.configuration = configuration

        super.init()
    }
}

extension ModalSheetPresentationFactory: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ModalSheetPresentationAppearanceAnimator(animator: configuration.contentAppearanceAnimator)
    }

    public func animationController(forDismissed dismissed: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        return ModalSheetPresentationDismissAnimator(animator: configuration.contentDissmisalAnimator,
                                                     finalPositionOffset: configuration.style.headerStyle?.preferredHeight ?? 0.0)
    }

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                       source: UIViewController) -> UIPresentationController? {
        presentation = ModalSheetPresentationController(presentedViewController: presented,
                                                        presenting: presenting,
                                                        configuration: configuration)
        return presentation
    }

    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return presentation?.interactiveDismissal
    }
}

public final class ModalSheetPresentationAppearanceAnimator: NSObject {
    let animator: BlockViewAnimatorProtocol

    public init(animator: BlockViewAnimatorProtocol) {
        self.animator = animator

        super.init()
    }
}

extension ModalSheetPresentationAppearanceAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animator.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .to) else {
            return
        }

        let finalFrame = transitionContext.finalFrame(for: presentedController)
        var initialFrame = finalFrame
        initialFrame.origin.y += finalFrame.size.height

        presentedController.view.frame = initialFrame
        transitionContext.containerView.addSubview(presentedController.view)

        let animationBlock: () -> Void = {
            presentedController.view.frame = finalFrame
        }

        let completionBlock: (Bool) -> Void = { finished in
            transitionContext.completeTransition(finished)
        }

        animator.animate(block: animationBlock, completionBlock: completionBlock)
    }
}

public final class ModalSheetPresentationDismissAnimator: NSObject {
    let animator: BlockViewAnimatorProtocol
    let finalPositionOffset: CGFloat

    public init(animator: BlockViewAnimatorProtocol, finalPositionOffset: CGFloat) {
        self.animator = animator
        self.finalPositionOffset = finalPositionOffset

        super.init()
    }
}

extension ModalSheetPresentationDismissAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animator.duration
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

        let completionBlock: (Bool) -> Void = { finished in
            if !transitionContext.transitionWasCancelled {
                presentedController.view.removeFromSuperview()
            }

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animator.animate(block: animationBlock, completionBlock: completionBlock)
    }
}
