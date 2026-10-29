import Foundation
import SoraUI
import UIKit
import SnapKit

// swiftlint:disable type_name
final class ModalSheetBlurPresentationAppearanceAnimator: NSObject {
    static let UITransitionViewFearlessTag = 130_130
    static let UIVisualEffectViewFearlessTag = 013_013

    private let animator: BlockViewAnimatorProtocol

    init(animator: BlockViewAnimatorProtocol) {
        self.animator = animator

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
        let presentationBounds = containerView.bounds

        var beginFrame = presentationBounds
        beginFrame.origin.y = presentationBounds.maxY
        toViewController.view.frame = beginFrame

        containerView.insertSubview(toViewController.view, aboveSubview: fromViewController.view)
        let fillsHeight = (toViewController as? SheetAletViewController)?.scrollableContent == true
        let showsCard = AdaptiveLayout.isRegularWidth(containerView.traitCollection)
        if showsCard {
            layoutAsCard(toViewController.view, in: containerView, fillsHeight: fillsHeight)
        } else {
            toViewController.view.snp.makeConstraints { make in
                if fillsHeight {
                    make.top.equalTo(containerView.safeAreaLayoutGuide.snp.top)
                } else {
                    make.top.greaterThanOrEqualTo(containerView.safeAreaLayoutGuide.snp.top)
                }
                make.bottom.equalTo(containerView.snp.bottom)
                make.width.equalTo(containerView.snp.width)
            }
        }
        toViewController.view.layoutIfNeeded()

        if showsCard {
            toViewController.view.transform = CGAffineTransform(translationX: 0, y: containerView.bounds.height)
        }

        let animationBlock: () -> Void = {
            if showsCard {
                toViewController.view.transform = .identity
            } else {
                toViewController.view.frame = presentationBounds
            }
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

    /// In a regular-width iPad window a bottom sheet would stretch across the whole
    /// screen; show it as a centered card that keeps its content height instead.
    /// A sheet whose content scrolls has no height of its own and fills the space
    /// between the margins.
    private func layoutAsCard(_ view: UIView, in containerView: UIView, fillsHeight: Bool) {
        view.layer.cornerRadius = AdaptiveLayout.sheetCornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.snp.makeConstraints { make in
            make.centerX.equalTo(containerView.safeAreaLayoutGuide.snp.centerX)
            make.centerY.equalTo(containerView.safeAreaLayoutGuide.snp.centerY).priority(.high)
            make.width.equalTo(AdaptiveLayout.sheetWidth).priority(.high)
            make.width.lessThanOrEqualTo(containerView.safeAreaLayoutGuide.snp.width)
                .offset(-2 * AdaptiveLayout.sheetMargin)
            if fillsHeight {
                make.top.equalTo(containerView.safeAreaLayoutGuide.snp.top).offset(AdaptiveLayout.sheetMargin)
                make.bottom.equalTo(containerView.safeAreaLayoutGuide.snp.bottom).offset(-AdaptiveLayout.sheetMargin)
            } else {
                make.top.greaterThanOrEqualTo(containerView.safeAreaLayoutGuide.snp.top)
                    .offset(AdaptiveLayout.sheetMargin)
                make.bottom.lessThanOrEqualTo(containerView.safeAreaLayoutGuide.snp.bottom)
                    .offset(-AdaptiveLayout.sheetMargin)
            }
        }
    }
}
