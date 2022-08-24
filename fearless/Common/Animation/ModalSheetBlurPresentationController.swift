import UIKit
import SoraUI

final class ModalSheetBlurPresentationController: UIPresentationController {
    private let configuration: ModalSheetPresentationConfiguration

    var interactiveDismissal: UIPercentDrivenInteractiveTransition?
    private var initialTranslation: CGPoint = .zero

    var presenterDelegate: ModalPresenterDelegate? {
        (presentedViewController as? ModalPresenterDelegate) ??
            (presentedView as? ModalPresenterDelegate) ??
            (presentedViewController.view as? ModalPresenterDelegate)
    }

    var sheetPresenterDelegate: ModalSheetPresenterDelegate? {
        presenterDelegate as? ModalSheetPresenterDelegate
    }

    var inputView: ModalViewProtocol? {
        (presentedViewController as? ModalViewProtocol) ??
            (presentedView as? ModalViewProtocol) ??
            (presentedViewController.view as? ModalViewProtocol)
    }

    init(
        presentedViewController: UIViewController,
        presenting presentingViewController: UIViewController?,
        configuration: ModalSheetPresentationConfiguration
    ) {
        self.configuration = configuration

        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)

        if let modalInputView = inputView {
            modalInputView.presenter = self
        }
    }

    private func attachCancellationGestureOnBlur() {
        let cancellationGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(actionDidCancel(gesture:))
        )
        cancellationGesture.cancelsTouchesInView = false

        let blur = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blur)
        blurView.tag = ModalSheetBlurPresentationAppearanceAnimator.UIVisualEffectViewFearlessTag
        blurView.frame = containerView?.bounds ?? .zero
        blurView.addGestureRecognizer(cancellationGesture)

        containerView?.addSubview(blurView)
    }

    private func attachPanGesture() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(sender:)))
        containerView?.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
    }

    // MARK: Presentation overridings

    override func presentationTransitionWillBegin() {
        attachCancellationGestureOnBlur()
        attachPanGesture()

        animateBackgroundAlpha(fromValue: 0.0, toValue: 1)
    }

    override func dismissalTransitionWillBegin() {
        if
            let window = UIApplication.shared.keyWindow,
            let transitionView = window.subviews.first(
                where: { $0.tag == ModalSheetBlurPresentationAppearanceAnimator.UITransitionViewFearlessTag }
            ),
            let blurView = transitionView.subviews.first(
                where: { $0.tag == ModalSheetBlurPresentationAppearanceAnimator.UIVisualEffectViewFearlessTag }
            ) {
            blurView.alpha = 1
        }
        animateBackgroundAlpha(fromValue: 1.0, toValue: 0.0)
    }

    // MARK: Animation

    func animateBackgroundAlpha(fromValue: CGFloat, toValue: CGFloat) {
        containerView?.alpha = fromValue

        let animationBlock: (UIViewControllerTransitionCoordinatorContext) -> Void = { _ in
            self.containerView?.alpha = toValue
        }

        presentingViewController.transitionCoordinator?
            .animate(alongsideTransition: animationBlock, completion: nil)
    }

    func dismiss(animated: Bool) {
        presentedViewController.dismiss(animated: animated, completion: nil)
    }

    // MARK: Action

    @objc private func actionDidCancel(gesture _: UITapGestureRecognizer) {
        guard let presenterDelegate = presenterDelegate else {
            dismiss(animated: true)
            return
        }

        if presenterDelegate.presenterShouldHide(self) {
            dismiss(animated: true)
            presenterDelegate.presenterDidHide(self)
        }
    }

    // MARK: Interactive dismissal

    @objc private func didPan(sender: Any?) {
        guard
            let panGestureRecognizer = sender as? UIPanGestureRecognizer,
            let view = panGestureRecognizer.view
        else { return }

        handlePan(from: panGestureRecognizer, on: view)
    }

    private func handlePan(from panGestureRecognizer: UIPanGestureRecognizer, on view: UIView) {
        let translation = panGestureRecognizer.translation(in: view)
        let velocity = panGestureRecognizer.velocity(in: view)

        switch panGestureRecognizer.state {
        case .began, .changed:
            if sheetPresenterDelegate?.presenterCanDrag(self) == false {
                return
            }
            if let interactiveDismissal = interactiveDismissal {
                let max = max(0.0, (translation.y - initialTranslation.y) / max(1.0, view.bounds.size.height))
                let progress = min(1.0, max)

                interactiveDismissal.update(progress)
            } else {
                if let presenterDelegate = presenterDelegate, !presenterDelegate.presenterShouldHide(self) {
                    break
                }

                interactiveDismissal = UIPercentDrivenInteractiveTransition()
                initialTranslation = translation
                presentedViewController.dismiss(animated: true)
            }
        case .cancelled, .ended:
            if let interactiveDismissal = interactiveDismissal {
                let thresholdReached = interactiveDismissal.percentComplete >= configuration.dismissPercentThreshold
                let shouldDismiss = (thresholdReached && velocity.y >= 0) ||
                    (velocity.y >= configuration.dismissVelocityThreshold && translation.y >= configuration.dismissMinimumOffset)
                stopPullToDismiss(finished: panGestureRecognizer.state != .cancelled && shouldDismiss)
            }
        default:
            break
        }
    }

    private func stopPullToDismiss(finished: Bool) {
        guard let interactiveDismissal = interactiveDismissal else {
            return
        }

        self.interactiveDismissal = nil

        if finished {
            interactiveDismissal.completionSpeed = configuration.dismissFinishSpeedFactor
            interactiveDismissal.finish()

            presenterDelegate?.presenterDidHide(self)
        } else {
            interactiveDismissal.completionSpeed = configuration.dismissCancelSpeedFactor
            interactiveDismissal.cancel()
        }
    }
}

extension ModalSheetBlurPresentationController: ModalPresenterProtocol {
    func hide(view _: ModalViewProtocol, animated: Bool) {
        guard interactiveDismissal == nil else {
            return
        }

        dismiss(animated: animated)
    }
}

extension ModalSheetBlurPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        guard let scrollView = otherGestureRecognizer.view as? UIScrollView else {
            return true
        }

        if scrollView.isTracking {
            return false
        }

        return true
    }
}
