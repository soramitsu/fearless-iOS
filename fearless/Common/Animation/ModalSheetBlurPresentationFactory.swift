import UIKit
import SoraUI

final class ModalSheetBlurPresentationFactory: NSObject {
    private let configuration: ModalSheetPresentationConfiguration

    private var presentation: ModalSheetBlurPresentationController?

    init(
        configuration: ModalSheetPresentationConfiguration
    ) {
        self.configuration = configuration

        super.init()
    }
}

extension ModalSheetBlurPresentationFactory: UIViewControllerTransitioningDelegate {
    public func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        ModalSheetBlurPresentationAppearanceAnimator(
            animator: configuration.contentAppearanceAnimator
        )
    }

    public func animationController(forDismissed _: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        ModalSheetBlurPresentationDismissAnimator(
            animator: configuration.contentDissmisalAnimator,
            finalPositionOffset: configuration.style.headerStyle?.preferredHeight ?? 0.0
        )
    }

    public func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source _: UIViewController
    ) -> UIPresentationController? {
        presentation = ModalSheetBlurPresentationController(
            presentedViewController: presented,
            presenting: presenting,
            configuration: configuration
        )
        return presentation
    }

    public func interactionControllerForDismissal(
        using _: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        presentation?.interactiveDismissal
    }
}
