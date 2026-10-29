import UIKit
import SoraUI

final class ModalSheetBlurPresentationFactory: NSObject {
    private let configuration: ModalSheetPresentationConfiguration
    private let shouldDissmissWhenTapOnBlurArea: Bool
    private let usesPreferredContentSize: Bool
    private weak var presentation: ModalSheetBlurPresentationController?

    init(
        configuration: ModalSheetPresentationConfiguration,
        shouldDissmissWhenTapOnBlurArea: Bool = true,
        usesPreferredContentSize: Bool = false
    ) {
        self.configuration = configuration
        self.shouldDissmissWhenTapOnBlurArea = shouldDissmissWhenTapOnBlurArea
        self.usesPreferredContentSize = usesPreferredContentSize

        super.init()
    }

    /// Pickers supply a preferred height rather than an intrinsic table height.
    /// Keep their existing iPhone presentation and use resizable cards on iPad.
    static func forPicker(
        configuration: ModalSheetPresentationConfiguration,
        idiom: UIUserInterfaceIdiom = UIDevice.current.userInterfaceIdiom
    ) -> UIViewControllerTransitioningDelegate {
        if idiom == .pad {
            return ModalSheetBlurPresentationFactory(configuration: configuration, usesPreferredContentSize: true)
        }
        return ModalSheetPresentationFactory(configuration: configuration)
    }
}

extension ModalSheetBlurPresentationFactory: UIViewControllerTransitioningDelegate {
    func animationController(
        forPresented _: UIViewController,
        presenting _: UIViewController,
        source _: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        if usesPreferredContentSize {
            return ModalSheetPresentationAppearanceAnimator(animator: configuration.contentAppearanceAnimator)
        }
        return ModalSheetBlurPresentationAppearanceAnimator(
            animator: configuration.contentAppearanceAnimator
        )
    }

    func animationController(forDismissed _: UIViewController)
        -> UIViewControllerAnimatedTransitioning? {
        ModalSheetBlurPresentationDismissAnimator(
            animator: configuration.contentDissmisalAnimator,
            finalPositionOffset: configuration.style.headerStyle?.preferredHeight ?? 0.0
        )
    }

    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source _: UIViewController
    ) -> UIPresentationController? {
        let controller = ModalSheetBlurPresentationController(
            presentedViewController: presented,
            presenting: presenting,
            configuration: configuration,
            shouldDissmissWhenTapOnBlurArea: shouldDissmissWhenTapOnBlurArea,
            usesPreferredContentSize: usesPreferredContentSize
        )
        presentation = controller
        return controller
    }

    /// iPad pickers follow the finger as SoraUI's picker sheets do on iPhone. Other
    /// sheets keep their existing pull-to-dismiss behavior.
    func interactionControllerForDismissal(
        using _: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        guard usesPreferredContentSize else {
            return nil
        }
        return presentation?.interactiveDismissal
    }
}
