/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

private struct EmptyStateConstants {
    static var viewKey: UInt8 = 0
    static var constraintsKey: UInt8 = 0
}

public extension EmptyStateViewOwnerProtocol where Self: UIViewController {

    private var emptyStateView: UIView? {
        get {
            return objc_getAssociatedObject(self,
                                            &EmptyStateConstants.viewKey) as? UIView
        }

        set {
            objc_setAssociatedObject(self,
                                     &EmptyStateConstants.viewKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private var constraints: [NSLayoutConstraint] {
        get {
            let constraints = objc_getAssociatedObject(self,
                                                       &EmptyStateConstants.constraintsKey) as? [NSLayoutConstraint]

            return constraints ?? []
        }

        set {
            objc_setAssociatedObject(self,
                                     &EmptyStateConstants.constraintsKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN)
        }
    }

    private func createDefaultEmptyStateView() -> EmptyStateView {
        let emptyStateView = EmptyStateView()
        emptyStateView.image = emptyStateDataSource.imageForEmptyState
        emptyStateView.title = emptyStateDataSource.titleForEmptyState
        emptyStateView.trimStrategy = emptyStateDataSource.trimStrategyForEmptyState

        if let verticalSpacing = emptyStateDataSource.verticalSpacingForEmptyState {
            emptyStateView.verticalSpacing = verticalSpacing
        }

        if let titleColor = emptyStateDataSource.titleColorForEmptyState {
            emptyStateView.titleColor = titleColor
        }

        if let font = emptyStateDataSource.titleFontForEmptyState {
            emptyStateView.titleFont = font
        }

        return emptyStateView
    }

    private func addEmptyStateView() {
        guard emptyStateView == nil else {
            return
        }

        let newEmptyStateView = emptyStateDataSource.viewForEmptyState ?? createDefaultEmptyStateView()
        let contentView = contentViewForEmptyState
        contentView.addSubview(newEmptyStateView)

        self.emptyStateView = newEmptyStateView
    }

    private func setupEmptyStateLayout() {
        guard let emptyStateView = emptyStateView else {
            return
        }

        let currentConstraints = constraints

        if currentConstraints.count > 0 {
            NSLayoutConstraint.deactivate(currentConstraints)
        }

        emptyStateView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = contentViewForEmptyState

        let displayInsets = displayInsetsForEmptyState

        let leading = emptyStateView.leadingAnchor.constraint(
            equalTo: contentView.leadingAnchor,
            constant: displayInsets.left
            )

        leading.isActive = true

        let tralling = emptyStateView.trailingAnchor.constraint(
            equalTo: contentView.trailingAnchor,
            constant: -displayInsets.right
            )

        tralling.isActive = true

        let top = emptyStateView.topAnchor.constraint(
            equalTo: contentView.topAnchor,
            constant: displayInsets.top
            )

        top.isActive = true


        let bottom = emptyStateView.bottomAnchor.constraint(
            equalTo: contentView.bottomAnchor,
            constant: -displayInsets.bottom
            )

        bottom.isActive = true

        constraints = [leading, tralling, top, bottom]
    }

    func reloadEmptyState(animated: Bool) {
        if emptyStateDelegate.shouldDisplayEmptyState {
            emptyStateView?.removeFromSuperview()
            emptyStateView = nil
            constraints = []

            addEmptyStateView()
            setupEmptyStateLayout()

            if animated,
                let animator = appearanceAnimatorForEmptyState,
                let emptyStateView = emptyStateView {
                animator.animate(view: emptyStateView,
                                 completionBlock: nil)
            }
        } else {
            guard let emptyStateView = emptyStateView else {
                return
            }

            self.emptyStateView = nil
            self.constraints = []

            let completionBlock = { (completed: Bool) -> Void in
                if completed {
                 emptyStateView.removeFromSuperview()
                }
            }

            if animated, let animator = dismissAnimatorForEmptyState {
                animator.animate(view: emptyStateView,
                                 completionBlock: completionBlock)
            } else {
                completionBlock(true)
            }
        }
    }

    func updateEmptyState(animated: Bool) {
        let shouldDisplay = emptyStateDelegate.shouldDisplayEmptyState
        let hasEmptyState = emptyStateView != nil

        if shouldDisplay != hasEmptyState {
            reloadEmptyState(animated: animated)
        }
    }

    func updateEmptyStateInsets() {
        guard let emptyStateView = emptyStateView else {
            return
        }

        setupEmptyStateLayout()

        emptyStateView.superview?.setNeedsLayout()
    }

    var contentViewForEmptyState: UIView {
        return view
    }

    var displayInsetsForEmptyState: UIEdgeInsets {
        return .zero
    }

    var appearanceAnimatorForEmptyState: ViewAnimatorProtocol? {
        return TransitionAnimator(type: .reveal)
    }
    var dismissAnimatorForEmptyState: ViewAnimatorProtocol? {
        return nil
    }

    var imageForEmptyState: UIImage? { nil }
    var titleForEmptyState: String? { nil }
    var titleColorForEmptyState: UIColor? { nil }
    var titleFontForEmptyState: UIFont? { nil }
    var verticalSpacingForEmptyState: CGFloat? { nil }
    var trimStrategyForEmptyState: EmptyStateView.TrimStrategy { .none }
}
