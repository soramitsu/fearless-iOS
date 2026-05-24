import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation

public class ModalAlertPresentationFactory: NSObject {
    let configuration: ModalAlertPresentationConfiguration

    public init(configuration: ModalAlertPresentationConfiguration) {
        self.configuration = configuration

        super.init()
    }
}

extension ModalAlertPresentationFactory: UIViewControllerTransitioningDelegate {

    public func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                                    source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        ModalAlertPresentationAppearanceAnimator(animator: configuration.contentAppearanceAnimator)
    }

    public func animationController(forDismissed dismissed: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        ModalAlertPresentationDismissAnimator(animator: configuration.contentDissmisalAnimator)
    }

    public func presentationController(forPresented presented: UIViewController, presenting: UIViewController?,
                                       source: UIViewController) -> UIPresentationController? {
        ModalAlertPresentationController(presentedViewController: presented,
                                         presenting: presenting,
                                         configuration: configuration)
    }
}

public final class ModalAlertPresentationAppearanceAnimator: NSObject {
    let animator: ViewAnimatorProtocol

    public init(animator: ViewAnimatorProtocol) {
        self.animator = animator

        super.init()
    }
}

extension ModalAlertPresentationAppearanceAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animator.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .to) else {
            return
        }

        presentedController.view.frame = transitionContext.finalFrame(for: presentedController)
        transitionContext.containerView.addSubview(presentedController.view)

        let completionBlock: (Bool) -> Void = { finished in
            transitionContext.completeTransition(finished)
        }

        animator.animate(view: presentedController.view, completionBlock: completionBlock)
    }
}

public final class ModalAlertPresentationDismissAnimator: NSObject {
    let animator: ViewAnimatorProtocol

    public init(animator: ViewAnimatorProtocol) {
        self.animator = animator

        super.init()
    }
}

extension ModalAlertPresentationDismissAnimator: UIViewControllerAnimatedTransitioning {
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return animator.duration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let presentedController = transitionContext.viewController(forKey: .from) else {
            return
        }

        let completionBlock: (Bool) -> Void = { finished in
            if !transitionContext.transitionWasCancelled {
                presentedController.view.removeFromSuperview()
            }

            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }

        animator.animate(view: presentedController.view, completionBlock: completionBlock)
    }
}
