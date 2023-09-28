import Foundation

import UIKit
import SoraUI

class ContainerViewController: UIViewController, AdaptiveDesignable {
    private enum Constants {
        static let minimumBottonInset: CGFloat = 60.0
        static let contentAnimationDuration: TimeInterval = 0.25
        static let draggableChangeDuration: TimeInterval = 0.25
        static let draggableCancellationThreshold: Double = 0.1
        static let draggableChangesAfterThreshold: Double = 0.5
        static let draggableVelocityThreshold: CGFloat = 20.0
        static let draggableMaxShadowAlpha: CGFloat = 0.5
    }

    private var shadowView: UIView?

    private var containerSize = CGSize(width: 375.0, height: 667.0)
    private var boundsHeight: CGFloat = 667.0

    var presentationNavigationItem: UINavigationItem? {
        nil
    }

    private var draggableState: DraggableState = .compact

    var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.bounces = true

        return scrollView
    }()

    var refreshControl = UIRefreshControl()

    var content: Containable?

    var draggable: Draggable?

    var gestureStartOriginY: CGFloat = 0.0

    var shouldInsertShadow: Bool = true

    var inheritedInsets: UIEdgeInsets {
        var contentInsets: UIEdgeInsets = .zero

        if #available(iOS 11.0, *) {
            contentInsets.top = view.safeAreaInsets.top
            contentInsets.bottom = view.safeAreaInsets.bottom
        } else {
            contentInsets.top = min(
                UIApplication.shared.statusBarFrame.size.width,
                UIApplication.shared.statusBarFrame.size.height
            )
        }

        if let view = viewIfLoaded {
            contentInsets.bottom += containerSize.height - view.bounds.height
        }

        return contentInsets
    }

    var draggableProgress: Double {
        guard let draggable = draggable else {
            return 0.0
        }

        let compactFrame = createDraggableFrame(for: .compact)
        let fullFrame = createDraggableFrame(for: .full)

        let maxDistance = abs(fullFrame.minY - compactFrame.minY)

        guard maxDistance > 0.0 else {
            return 0.0
        }

        let otherFrame = createDraggableFrame(for: draggableState)
        let remainedDistance = abs(draggable.draggableView.frame.minY - otherFrame.minY)

        return Double(remainedDistance / maxDistance)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        adjustLayout()
        updateContentLayout()
        updateDraggableLayout()
        updateContentInsets()
        updateDraggableContentInsets()

        setupScrollView()
        setupContentView()
        setupDraggableView()

        configurePanRecognizer()
    }

    @available(iOS 11.0, *)
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        updateContentInsets()
        updateDraggableLayout()
        updateDraggableContentInsets()
    }

    @objc private func handleRefresh() {
        refreshControl.endRefreshing()
        if let reloadableContent = content as? Reloadable {
            reloadableContent.reload()
        }
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if abs(boundsHeight - view.bounds.height) > CGFloat.leastNonzeroMagnitude {
            boundsHeight = view.bounds.height

            updateContentInsets()
            updateDraggableLayout()
            updateDraggableContentInsets()
        }
    }

    private func adjustLayout() {
        containerSize.width *= designScaleRatio.width
        containerSize.height *= designScaleRatio.height

        boundsHeight = view.bounds.height
    }

    private func configurePanRecognizer() {
        if let draggable = draggable {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            pan.maximumNumberOfTouches = 1
            pan.minimumNumberOfTouches = 1
            draggable.draggableView.addGestureRecognizer(pan)
        }
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(refreshControl)

        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
    }

    private func setupContentView() {
        if let content = content {
            if let contentController = content as? UIViewController {
                addChild(contentController)
            }

            scrollView.addSubview(content.contentView)
            content.contentView.autoresizingMask = []

            content.observable.add(observer: self)

            if let contentReloadable = content as? Reloadable {
                contentReloadable.reloadableDelegate = self
            }
        }
    }

    private func setupDraggableView() {
        if let draggable = draggable {
            if let draggableController = draggable as? UIViewController {
                addChild(draggableController)
            }

            scrollView.addSubview(draggable.draggableView)
            draggable.draggableView.autoresizingMask = []

            draggable.delegate = self

            if let draggableReloadable = draggable as? Reloadable {
                draggableReloadable.reloadableDelegate = self
            }
        }
    }

    private func setupShadowView() {
        if let draggable = draggable, shouldInsertShadow {
            let currentShadow: UIView

            if let shadowView = shadowView {
                currentShadow = shadowView
            } else {
                currentShadow = UIView()
                currentShadow.backgroundColor = .black
                shadowView = currentShadow
            }

            currentShadow.frame = view.bounds

            view.insertSubview(currentShadow, belowSubview: draggable.draggableView)
        }
    }

    fileprivate func updateContentInsets(animated: Bool = false) {
        if let content = content {
            let contentInsets = createPreferredContentInsets(for: content.preferredContentHeight)
            content.setContentInsets(contentInsets, animated: animated)
        }
    }

    fileprivate func updateDraggableContentInsets() {
        if let draggable = draggable {
            let fullContentInsets = inheritedInsets
            var compactContentInsets = fullContentInsets
            compactContentInsets.top = 0.0

            draggable.set(contentInsets: fullContentInsets, for: .full)
            draggable.set(contentInsets: compactContentInsets, for: .compact)
        }
    }

    fileprivate func updateContentLayout(forceLayoutUpdate: Bool = false) {
        if let content = content {
            content.contentView.frame = CGRect(x: 0.0, y: 0.0, width: containerSize.width, height: containerSize.height)

            if forceLayoutUpdate {
                content.contentView.layoutIfNeeded()
            }
        }
    }

    fileprivate func createPreferredContentInsets(for contentHeight: CGFloat) -> UIEdgeInsets {
        var contentInsets: UIEdgeInsets = inheritedInsets

        contentInsets.bottom += max(
            containerSize.height - contentInsets.top - contentInsets.bottom - contentHeight,
            Constants.minimumBottonInset
        )

        return contentInsets
    }

    fileprivate func createDraggableFrame(for state: DraggableState) -> CGRect {
        let preferredContentHeight = content?.preferredContentHeight ?? 0.0

        switch state {
        case .compact:
            let preferredContentInsets = createPreferredContentInsets(for: preferredContentHeight)

            let compactOriginY = containerSize.height - preferredContentInsets.bottom
            let compactHeight = preferredContentInsets.bottom
            return CGRect(
                x: 0.0,
                y: compactOriginY,
                width: containerSize.width,
                height: compactHeight
            )
        case .full:
            return CGRect(origin: .zero, size: containerSize)
        }
    }

    fileprivate func updateDraggableLayout(forceLayoutUpdate: Bool = false) {
        if let draggable = draggable {
            draggable.draggableView.frame = createDraggableFrame(for: draggableState)

            if forceLayoutUpdate {
                draggable.draggableView.layoutIfNeeded()
            }
        }
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let draggable = draggable else {
            return
        }

        switch recognizer.state {
        case .began:
            if draggableState == .compact {
                setupShadowView()
            }

            gestureStartOriginY = recognizer.location(in: draggable.draggableView.superview).y

            if draggable.canDrag(from: draggableState) {
                updateAnimationProgress(draggableFrame: draggable.draggableView.frame)
            }
        case .changed:
            let newY = recognizer.location(in: draggable.draggableView.superview).y
            let translation = newY - gestureStartOriginY
            gestureStartOriginY = newY

            let compactFrame = createDraggableFrame(for: .compact)
            let fullFrame = createDraggableFrame(for: .full)

            var newOriginY = draggable.draggableView.frame.origin.y + translation
            newOriginY = min(compactFrame.minY, newOriginY)
            newOriginY = max(fullFrame.minY, newOriginY)

            if draggable.canDrag(from: draggableState), draggable.draggableView.frame.origin.y != newOriginY {
                var frame = draggable.draggableView.frame
                frame.origin.y = newOriginY
                frame.size.height = containerSize.height - newOriginY

                updateAnimationProgress(draggableFrame: frame)
            }

        case .ended, .cancelled:
            let velocity = recognizer.velocity(in: view)
            completeStateTransitionAnimation(with: velocity)
        default:
            break
        }
    }

    private func updateAnimationProgress(draggableFrame: CGRect) {
        if let draggable = draggable {
            switch draggableState {
            case .compact:
                shadowView?.alpha = CGFloat(draggableProgress) * Constants.draggableMaxShadowAlpha
            case .full:
                shadowView?.alpha = CGFloat(1.0 - draggableProgress) * Constants.draggableMaxShadowAlpha
            }

            draggable.animate(
                progress: draggableProgress,
                from: draggableState,
                to: draggableState.other,
                finalFrame: draggableFrame
            )
        }
    }

    private func completeStateTransitionAnimation(with velocity: CGPoint) {
        guard let draggable = draggable else {
            return
        }

        let oppositPan = (velocity.y < 0.0 && draggableState == .full) ||
            (velocity.y > 0.0 && draggableState == .compact)

        if oppositPan || draggableProgress < Constants.draggableCancellationThreshold {
            let duration = Constants.draggableChangeDuration
            animateDraggable(to: draggableState, duration: duration)
            draggable.set(dragableState: draggableState, animated: true)
            return
        }

        if draggableProgress > Constants.draggableChangesAfterThreshold ||
            abs(velocity.y) > Constants.draggableVelocityThreshold {
            let duration = Constants.draggableChangeDuration

            draggableState = draggableState.other
            animateDraggable(to: draggableState, duration: duration)
            draggable.set(dragableState: draggableState, animated: true)
        } else {
            let duration = Constants.draggableChangeDuration
            animateDraggable(to: draggableState, duration: duration)
            draggable.set(dragableState: draggableState, animated: true)
        }
    }

    private func animateDraggable(to state: DraggableState, duration: TimeInterval) {
        if let draggable = draggable {
            let frame = createDraggableFrame(for: state)

            if state == .full {
                setupShadowView()
            }

            UIView.animate(withDuration: duration, animations: {
                draggable.draggableView.frame = frame
                draggable.draggableView.layoutIfNeeded()

                switch state {
                case .compact:
                    self.shadowView?.alpha = 0.0
                case .full:
                    self.shadowView?.alpha = Constants.draggableMaxShadowAlpha
                }

            }, completion: { _ in
                if state == .compact {
                    self.shadowView?.removeFromSuperview()
                    self.shadowView = nil
                }
            })
        }
    }
}

extension ContainerViewController: ContainableObserver {
    func willChangePreferredContentHeight() {
        CATransaction.begin()
        CATransaction.setAnimationDuration(Constants.contentAnimationDuration)

        UIView.beginAnimations(nil, context: nil)
        UIView.setAnimationDuration(Constants.contentAnimationDuration)
    }

    func didChangePreferredContentHeight(to _: CGFloat) {
        updateDraggableLayout(forceLayoutUpdate: true)
        updateContentInsets(animated: true)

        UIView.commitAnimations()
        CATransaction.commit()
    }
}

extension ContainerViewController: DraggableDelegate {
    func wantsTransit(to draggableState: DraggableState, animating: Bool) {
        if self.draggableState != draggableState {
            self.draggableState = draggableState

            if animating {
                animateDraggable(to: draggableState, duration: Constants.draggableChangeDuration)
                draggable?.set(dragableState: draggableState, animated: true)
            } else {
                updateDraggableLayout()

                switch draggableState {
                case .compact:
                    shadowView?.removeFromSuperview()
                    shadowView = nil
                case .full:
                    setupShadowView()
                }
            }
        }
    }
}

extension ContainerViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if let scrollPanRecognizer = draggable?.scrollPanRecognizer, scrollPanRecognizer === otherGestureRecognizer {
            return true
        } else {
            return false
        }
    }
}

extension ContainerViewController: ReloadableDelegate {
    func didInitiateReload(on reloadable: Reloadable) {
        if reloadable === content, let draggableReloadable = draggable as? Reloadable {
            draggableReloadable.reload()
        } else if reloadable === draggable, let containableReloadable = content as? Reloadable {
            containableReloadable.reload()
        }
    }
}
