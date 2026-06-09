/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

class ModalSheetPresentationController: UIPresentationController {
    let configuration: ModalSheetPresentationConfiguration

    private var backgroundView: UIView?
    private var headerView: RoundedView?

    var interactiveDismissal: UIPercentDrivenInteractiveTransition?
    var initialTranslation: CGPoint = .zero

    var presenterDelegate: ModalPresenterDelegate? {
        (presentedViewController as? ModalPresenterDelegate) ??
        (presentedView as? ModalPresenterDelegate) ??
        (presentedViewController.view as? ModalPresenterDelegate)
    }

    var sheetPresenterDelegate: ModalSheetPresenterDelegate? {
        return presenterDelegate as? ModalSheetPresenterDelegate
    }

    var inputView: ModalViewProtocol? {
        (presentedViewController as? ModalViewProtocol) ??
        (presentedView as? ModalViewProtocol) ??
        (presentedViewController.view as? ModalViewProtocol)
    }

    init(presentedViewController: UIViewController,
         presenting presentingViewController: UIViewController?,
         configuration: ModalSheetPresentationConfiguration) {

        self.configuration = configuration

        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)

        if let modalInputView = inputView {
            modalInputView.presenter = self
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

    private func configureHeaderView(on view: UIView, style: ModalSheetPresentationHeaderStyle) {
        let width = containerView?.bounds.width ?? view.bounds.width

        if let headerView = headerView {
            view.insertSubview(headerView, at: 0)
        } else {
            let baseView = RoundedView()
            baseView.cornerRadius = style.cornerRadius
            baseView.roundingCorners = [.topLeft, .topRight]
            baseView.fillColor = style.backgroundColor
            baseView.highlightedFillColor = style.backgroundColor
            baseView.shadowOpacity = 0.0

            let indicator = RoundedView()
            indicator.roundingCorners = .allCorners
            indicator.cornerRadius = style.indicatorSize.height / 2.0
            indicator.fillColor = style.indicatorColor
            indicator.highlightedFillColor = style.indicatorColor
            indicator.shadowOpacity = 0.0

            baseView.addSubview(indicator)

            let indicatorX = width / 2.0 - style.indicatorSize.width / 2.0
            indicator.frame = CGRect(origin: CGPoint(x: indicatorX, y: style.indicatorVerticalOffset), size: style.indicatorSize)

            view.insertSubview(baseView, at: 0)

            headerView = baseView
        }

        headerView?.frame = CGRect(x: 0.0,
                                   y: -style.preferredHeight + 0.5,
                                   width: width,
                                   height: style.preferredHeight)
    }

    private func attachCancellationGesture() {
        let cancellationGesture = UITapGestureRecognizer(target: self,
                                                         action: #selector(actionDidCancel(gesture:)))
        backgroundView?.addGestureRecognizer(cancellationGesture)
    }

    private func attachPanGesture() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(didPan(sender:)))
        containerView?.addGestureRecognizer(panGestureRecognizer)
        panGestureRecognizer.delegate = self
    }

    // MARK: Presentation overridings

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else {
            return
        }

        configureBackgroundView(on: containerView)

        if let headerStyle = configuration.style.headerStyle {
            configureHeaderView(on: presentedViewController.view, style: headerStyle)
        }

        attachCancellationGesture()
        attachPanGesture()

        animateBackgroundAlpha(fromValue: 0.0, toValue: 1.0)
    }

    override func dismissalTransitionWillBegin() {
        animateBackgroundAlpha(fromValue: 1.0, toValue: 0.0)
    }

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else {
            return .zero
        }

        let layoutFrame: CGRect
        let bottomOffset: CGFloat
        var maximumHeight = containerView.frame.size.height
        if #available(iOS 11.0, *) {
            if configuration.extendUnderSafeArea {
                layoutFrame = containerView.bounds
                bottomOffset = containerView.safeAreaInsets.bottom
                maximumHeight -= containerView.safeAreaInsets.top
            } else {
                layoutFrame = containerView.safeAreaLayoutGuide.layoutFrame
                bottomOffset = 0.0
            }
        } else {
            layoutFrame = containerView.bounds
            bottomOffset = 0.0
        }
        maximumHeight -= bottomOffset

        let preferredSize = presentedViewController.preferredContentSize
        let layoutWidth = preferredSize.width > 0.0 ? preferredSize.width : layoutFrame.width
        let layoutHeight = preferredSize.height > 0.0 ? preferredSize.height + bottomOffset : layoutFrame.height
        let height = min(layoutHeight, maximumHeight)

        return CGRect(x: layoutFrame.minX,
                      y: layoutFrame.maxY - height,
                      width: layoutWidth,
                      height: height)
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

    @objc func actionDidCancel(gesture: UITapGestureRecognizer) {
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

    @objc func didPan(sender: Any?) {
        guard let panGestureRecognizer = sender as? UIPanGestureRecognizer else { return }
        guard let view = panGestureRecognizer.view else { return }

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
                let progress = min(1.0, max(0.0, (translation.y - initialTranslation.y) / max(1.0, view.bounds.size.height)))

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

extension ModalSheetPresentationController: ModalPresenterProtocol {
    func hide(view: ModalViewProtocol, animated: Bool) {
        guard interactiveDismissal == nil else {
            return
        }

        dismiss(animated: animated)
    }
}

extension ModalSheetPresentationController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
}
