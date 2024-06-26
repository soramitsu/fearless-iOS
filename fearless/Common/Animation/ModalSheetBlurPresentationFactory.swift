import UIKit
import SoraUI

final class ModalSheetBlurPresentationFactory: NSObject {
    private let configuration: ModalSheetPresentationConfiguration
    private let shouldDissmissWhenTapOnBlurArea: Bool

    init(
        configuration: ModalSheetPresentationConfiguration,
        shouldDissmissWhenTapOnBlurArea: Bool = true
    ) {
        self.configuration = configuration
        self.shouldDissmissWhenTapOnBlurArea = shouldDissmissWhenTapOnBlurArea

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
        ModalSheetBlurPresentationController(
            presentedViewController: presented,
            presenting: presenting,
            configuration: configuration,
            shouldDissmissWhenTapOnBlurArea: shouldDissmissWhenTapOnBlurArea
        )
    }
}
