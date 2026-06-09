/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

/**
    Subclass of `UIControl` designed to provide tappable view consisting of background and content.
    Background is supposed to fill the bounds of the control and the content view is centered based on its
    intrinsic content size. Changes in isHighlighted and isSelected states are automatically forwarded to background
    and content when they are subclasses of `UIControl` or conform to Highlightable protocol.
 */
open class BackgroundedContentControl: UIControl {

    override open var isEnabled: Bool {
        didSet {
            applyEnabledState(when: isEnabled)
        }
    }

    /**
        Insets to control position of the content relatively to the center of the bounds.
        By default `UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)`
    */
    open var contentInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0) {
        didSet {
            invalidateLayout()
        }
    }

    /**
        Background view is intended to fill the entire bounds of the control.
        By default `nil`.
    */
    open var backgroundView: UIView? {
        willSet {
            guard let currentBackgroundView = backgroundView else { return }

            if currentBackgroundView != newValue { currentBackgroundView.removeFromSuperview() }

            invalidateLayout()
        }

        didSet {
            guard let currentBackgroundView = backgroundView else { return }

            applyHighlightedStateIfSupporting(view: currentBackgroundView, animated: false)

            if currentBackgroundView.superview != self {
                if let currentContentView = contentView {
                    self.insertSubview(currentBackgroundView, belowSubview: currentContentView)
                } else {
                    self.addSubview(currentBackgroundView)
                }
            }

            invalidateLayout()
        }
    }

    /**
        Content view is displayed above of background view and centered in bounds rectangle of the control.
        By default `nil`.
    */
    open var contentView: UIView? {
        willSet {
            guard let currentContentView = contentView else { return }

            if currentContentView != newValue { currentContentView.removeFromSuperview() }

            invalidateLayout()
        }

        didSet {
            guard let currentContentView = contentView else { return }

            applyContentHighlightedState(animated: false)

            if currentContentView.superview != self {
                if let currentBackgroundView = backgroundView {
                    self.insertSubview(currentContentView, aboveSubview: currentBackgroundView)
                } else {
                    self.addSubview(currentContentView)
                }
            }

            invalidateLayout()
        }
    }

    /**
        Changes opacity of the content view when control is highlighted. By default `false`.
     */
    open var changesContentOpacityWhenHighlighted: Bool = false {
        didSet {
            applyContentHighlightedState(animated: false)
        }
    }

    /**
        Opacity of the content view to apply when highlighted
    */
    open var contentOpacityWhenHighlighted: CGFloat = 0.5 {
        didSet {
            if changesContentOpacityWhenHighlighted {
                applyContentHighlightedState(animated: false)
            }
        }
    }

    /**
        Opacity of the content view to apply when disabled
     */
    open var contentOpacityWhenDisabled: CGFloat = 0.5 {
        didSet {
            applyEnabledState(when: isEnabled)
        }
    }

    /// Opacity animation duration
    open var opacityAnimationDuration: TimeInterval = 0.5

    /// Opacity animation options
    open var opacityAnimationOptions: UIView.AnimationOptions = UIView.AnimationOptions.curveEaseOut

    /// Use this method to force layout update instead of `setNeedsDisplay`.
    open func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: Overriden methods

    override open var isHighlighted: Bool {
        didSet {
            applyHighlightedStateIfSupporting(view: backgroundView, animated: false)
            applyContentHighlightedState(animated: false)
        }
    }

    open func set(highlighted: Bool, animated: Bool) {
        isHighlighted = highlighted

        if animated {
            applyHighlightedStateIfSupporting(view: backgroundView, animated: true)
            applyContentHighlightedState(animated: true)
        }
    }

    override open var isSelected: Bool {
        didSet {
            applyHighlightedStateIfSupporting(view: backgroundView, animated: false)
            applyContentHighlightedState(animated: false)
        }
    }

    override open var intrinsicContentSize: CGSize {
        guard let currentContentView = contentView else { return CGSize.zero }

        var width = contentInsets.left + contentInsets.right
        var height = contentInsets.top + contentInsets.bottom

        let contentSize = currentContentView.intrinsicContentSize
        width += contentSize.width
        height += contentSize.height

        return CGSize(width: width, height: height)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        backgroundView?.frame = bounds

        guard let currentContentView = contentView else { return }

        let contentSize = currentContentView.intrinsicContentSize
        let contentX = bounds.size.width / 2.0 - contentSize.width / 2.0
            + (contentInsets.left - contentInsets.right) / 2.0
        let contentY = bounds.size.height / 2.0 - contentSize.height / 2.0
            + (contentInsets.top - contentInsets.bottom) / 2.0

        currentContentView.frame = CGRect(origin: CGPoint(x: contentX, y: contentY), size: contentSize)
    }

    // MARK: Touch Handling

    override open func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let shouldAnimate = isHighlighted

        super.touchesEnded(touches, with: event)

        if shouldAnimate {
            set(highlighted: false, animated: true)
        }
    }

    // MARK: Private methods

    private func applyHighlightedStateIfSupporting(view: UIView?, animated: Bool) {
        if let control = view as? UIControl {
            control.isHighlighted = isHighlighted
            control.isSelected = isSelected
            return
        }

        if let highlightable = view as? Highlightable {
            let shouldAnimate = animated && !(isHighlighted  || isSelected)
            highlightable.set(highlighted: isHighlighted || isSelected, animated: shouldAnimate)
            return
        }
    }

    private func applyContentHighlightedState(animated: Bool) {
        resetContentHighlightedState()

        if !changesContentOpacityWhenHighlighted {
            applyHighlightedStateIfSupporting(view: contentView, animated: animated)
        } else {
            let shouldAnimate = animated && !(isHighlighted  || isSelected)
            let newValue =  (isHighlighted  || isSelected) ? contentOpacityWhenHighlighted : 1.0

            if !shouldAnimate {
                contentView?.alpha = newValue
            } else {
                contentView?.alpha = contentOpacityWhenHighlighted
                UIView.animate(withDuration: opacityAnimationDuration,
                               delay: 0.0,
                               options: opacityAnimationOptions,
                               animations: {
                                self.contentView?.alpha = newValue
                }, completion: nil)
            }
        }
    }

    private func resetContentHighlightedState() {
        contentView?.alpha = 1.0

        if let control = contentView as? UIControl {
            control.isHighlighted = false
            control.isSelected = false
        }

        if let highlightable = contentView as? Highlightable {
            highlightable.set(highlighted: false, animated: false)
        }
    }

    private func applyEnabledState(when enabled: Bool) {
        contentView?.alpha = enabled ? 1.0 : contentOpacityWhenDisabled
        backgroundView?.alpha = enabled ? 1.0 : contentOpacityWhenDisabled
    }
}

extension BackgroundedContentControl {
    @IBInspectable
    private var _highlighted: Bool {
        set(newValue) {
            self.isHighlighted = newValue
        }

        get {
            return self.isHighlighted
        }
    }

    @IBInspectable
    private var _enabled: Bool {
        set(newValue) {
            self.isEnabled = newValue
        }

        get {
            return self.isEnabled
        }
    }

    @IBInspectable
    private var _topInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: newValue,
                                              left: insets.left,
                                              bottom: insets.bottom,
                                              right: insets.right)
        }

        get {
            return self.contentInsets.top
        }
    }

    @IBInspectable
    private var _leftInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: newValue,
                                              bottom: insets.bottom,
                                              right: insets.right)
        }

        get {
            return self.contentInsets.top
        }
    }

    @IBInspectable
    private var _bottomInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: insets.left,
                                              bottom: newValue,
                                              right: insets.right)
        }

        get {
            return self.contentInsets.top
        }
    }

    @IBInspectable
    private var _rightInset: CGFloat {
        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: insets.left,
                                              bottom: insets.bottom,
                                              right: newValue)
        }

        get {
            return self.contentInsets.top
        }
    }
}
