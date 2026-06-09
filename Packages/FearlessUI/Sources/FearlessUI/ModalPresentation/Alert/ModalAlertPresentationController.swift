import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL 3.0
*/

import Foundation

class ModalAlertPresentationController: UIPresentationController {
    let configuration: ModalAlertPresentationConfiguration

    private var backgroundView: UIView?
    private var contentView: RoundedView?

    var interactiveDismissal: UIPercentDrivenInteractiveTransition?
    var initialTranslation: CGPoint = .zero

    var presenterDelegate: ModalPresenterDelegate? {
        (presentedViewController as? ModalPresenterDelegate) ??
        (presentedView as? ModalPresenterDelegate) ??
        (presentedViewController.view as? ModalPresenterDelegate)
    }

    var targetView: ModalViewProtocol? {
        (presentedViewController as? ModalViewProtocol) ??
        (presentedView as? ModalViewProtocol) ??
        (presentedViewController.view as? ModalViewProtocol)
    }

    deinit {
        cancelDismissalTimer()
    }

    init(presentedViewController: UIViewController,
         presenting presentingViewController: UIViewController?,
         configuration: ModalAlertPresentationConfiguration) {

        self.configuration = configuration

        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)

        if let inputView = targetView {
            inputView.presenter = self
        }
    }

    private func configureBackgroundView(on view: UIView) {
        if let currentBackgroundView = backgroundView {
            view.insertSubview(currentBackgroundView, at: 0)
        } else {
            let newBackgroundView = UIView(frame: view.bounds)

            newBackgroundView.backgroundColor = configuration.style.backdropColor

            view.insertSubview(newBackgroundView, at: 0)
            backgroundView = newBackgroundView
        }

        backgroundView?.frame = view.bounds
    }

    private func configureContentView(on view: UIView, style: ModalAlertPresentationStyle) {
        var contentSize = configuration.preferredSize

        if !(contentSize.width > 0.0) {
            contentSize.width = view.bounds.size.width
        }

        if !(contentSize.height > 0.0) {
            contentSize.height = view.bounds.size.height
        }

        if let contentView = contentView {
            view.insertSubview(contentView, at: 0)
        } else {
            let baseView = RoundedView()
            baseView.cornerRadius = style.cornerRadius
            baseView.roundingCorners = .allCorners
            baseView.fillColor = style.backgroundColor
            baseView.highlightedFillColor = style.backgroundColor
            baseView.shadowOpacity = 0.0

            view.insertSubview(baseView, at: 0)

            contentView = baseView
        }

        let centerX = contentSize.width / 2.0 + (configuration.contentOffset.left - configuration.contentOffset.right) / 2.0
        let centerY = contentSize.height / 2.0 + (configuration.contentOffset.top - configuration.contentOffset.bottom) / 2.0

        contentView?.frame = CGRect(x: centerX - contentSize.width / 2.0,
                                    y: centerY - contentSize.height / 2.0,
                                    width: contentSize.width,
                                    height: contentSize.height)
    }

    private func attachCancellationGesture() {
        let cancellationGesture = UITapGestureRecognizer(target: self,
                                                         action: #selector(actionDidCancel))
        backgroundView?.addGestureRecognizer(cancellationGesture)
    }

    // MARK: Presentation overridings

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else {
            return
        }

        configureBackgroundView(on: containerView)

        configureContentView(on: presentedViewController.view, style: configuration.style)

        attachCancellationGesture()

        animateBackgroundAlpha(fromValue: 0.0, toValue: 1.0)

        applyCompletionFeedbackIfNeeded()
    }

    override func presentationTransitionDidEnd(_ completed: Bool) {
        if configuration.dismissAfterDelay > 0.0 {
            perform(#selector(actionDidCancel), with: self, afterDelay: configuration.dismissAfterDelay)
        }
    }

    override func dismissalTransitionWillBegin() {
        animateBackgroundAlpha(fromValue: 1.0, toValue: 0.0)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else {
            return .zero
        }

        let centerX = containerView.bounds.midX + (configuration.contentOffset.left - configuration.contentOffset.right) / 2.0
        let centerY = containerView.bounds.midY + (configuration.contentOffset.top - configuration.contentOffset.bottom) / 2.0

        return CGRect(x: centerX - configuration.preferredSize.width / 2.0,
                      y: centerY - configuration.preferredSize.height / 2.0,
                      width: configuration.preferredSize.width,
                      height: configuration.preferredSize.height)
    }

    private func cancelDismissalTimer() {
        NSObject.cancelPreviousPerformRequests(withTarget: self,
                                               selector: #selector(actionDidCancel),
                                               object: nil)
    }

    private func applyCompletionFeedbackIfNeeded() {
        if #available(iOS 10.0, *) {
            let type: UINotificationFeedbackGenerator.FeedbackType
            switch configuration.completionFeedback {
            case .none:
                return
            case .success:
                type = .success
            case .warning:
                type = .warning
            case .error:
                type = .error
            }

            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(type)
        }
    }

    // MARK: Animation

    func animateBackgroundAlpha(fromValue: CGFloat, toValue: CGFloat) {
        backgroundView?.alpha = fromValue

        let animationBlock: (UIViewControllerTransitionCoordinatorContext) -> Void = { _ in
            self.backgroundView?.alpha = toValue
        }

        presentingViewController.transitionCoordinator?
            .animate(alongsideTransition: animationBlock, completion: nil)
    }

    func dismiss(animated: Bool) {
        presentedViewController.dismiss(animated: animated, completion: nil)
    }

    // MARK: Action

    @objc func actionDidCancel() {
        cancelDismissalTimer()

        guard let presenterDelegate = presenterDelegate else {
            dismiss(animated: true)
            return
        }

        if presenterDelegate.presenterShouldHide(self) {
            dismiss(animated: true)
            presenterDelegate.presenterDidHide(self)
        }
    }
}

extension ModalAlertPresentationController: ModalPresenterProtocol {
    func hide(view: ModalViewProtocol, animated: Bool) {
        guard interactiveDismissal == nil else {
            return
        }

        dismiss(animated: animated)
    }
}

extension ModalAlertPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
