import UIKit
/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import Foundation

public protocol ActionControlIndicatorProtocol {
    var isActivated: Bool { get }

    func activate()
    func deactivate()
}

public typealias ActionControlIndicatorView = ActionControlIndicatorProtocol & UIView

open class BaseActionControl: UIControl {
    public enum LayoutType: UInt {
        case fixed
        case flexible
    }

    private struct Constants {
        static let activationAnimationDuration: TimeInterval = 0.25
        static let highlightedAlpha: CGFloat = 0.5
    }

    open var title: UIView? {
        willSet {
            guard let currentTitle = title else { return }

            if currentTitle !== newValue { currentTitle.removeFromSuperview() }

            invalidateLayout()
        }

        didSet {
            guard let currentTitle = title else { return }

            if currentTitle.superview != self {
                if let indicator = indicator {
                    self.insertSubview(currentTitle, aboveSubview: indicator)
                } else {
                    self.addSubview(currentTitle)
                }
            }

            invalidateLayout()
        }
    }

    open var indicator: ActionControlIndicatorView? {
        willSet {
            guard let currentIndicator = indicator else { return }

            if currentIndicator !== newValue { currentIndicator.removeFromSuperview() }

            invalidateLayout()
        }

        didSet {
            guard let currentIndicator = indicator else { return }

            if currentIndicator.superview != self {
                if let title = title {
                    self.insertSubview(currentIndicator, belowSubview: title)
                } else {
                    self.addSubview(currentIndicator)
                }
            }

            invalidateLayout()
        }
    }

    public var isActivated: Bool { indicator?.isActivated ?? false }

    open var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            invalidateLayout()
        }
    }

    open var verticalDisplacement: CGFloat = 0.0 {
        didSet {
            invalidateLayout()
        }
    }

    open var layoutType: LayoutType = .fixed {
        didSet {
            invalidateLayout()
        }
    }

    open var contentInsets: UIEdgeInsets = .zero {
        didSet {
            invalidateLayout()
        }
    }

    // MARK: Initialization

    override public init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    private func configure() {
        addTarget(self, action: #selector(actionOnTouchUpInside(sender:)), for: .touchUpInside)
    }

    // MARK: Layout

    override open var intrinsicContentSize: CGSize {
        let titleSize = title?.intrinsicContentSize ?? .zero
        let indicatorSize = indicator?.intrinsicContentSize ?? .zero

        let contentHeight = max(titleSize.height, indicatorSize.height)

        let preferredWidth = titleSize.width + horizontalSpacing
            + indicatorSize.width
        let contentWidth = max(preferredWidth, 0.0)

        return CGSize(width: contentWidth + contentInsets.left + contentInsets.right,
                      height: contentHeight + contentInsets.top + contentInsets.bottom)
    }

    override open func sizeToFit() {
        let newOrigin = CGPoint(x: frame.midX - intrinsicContentSize.width / 2.0,
                                y: frame.midY - intrinsicContentSize.height / 2.0)
        frame = CGRect(origin: newOrigin, size: intrinsicContentSize)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        var titleSize = title?.intrinsicContentSize ?? .zero
        var contentSize = intrinsicContentSize
        let indicatorSize = indicator?.intrinsicContentSize ?? .zero

        if bounds.width < contentSize.width {
            titleSize.width = bounds.width - horizontalSpacing - indicatorSize.width
                - contentInsets.left - contentInsets.right
            contentSize.width = bounds.width
        }

        let titleOrigin: CGPoint
        let indicatorOrigin: CGPoint

        switch layoutType {
        case .fixed:
            let titleX = bounds.midX - contentSize.width / 2.0 + contentInsets.left
            let titleY = contentInsets.top / 2.0 + bounds.midY - titleSize.height / 2.0 - contentInsets.bottom / 2.0
            titleOrigin = CGPoint(x: titleX,
                                  y: titleY)

            let indicatorY = contentInsets.top / 2.0 + bounds.midY - indicatorSize.height / 2.0
                + verticalDisplacement - contentInsets.bottom / 2.0
            indicatorOrigin = CGPoint(x: titleOrigin.x + titleSize.width + horizontalSpacing,
                                      y: indicatorY)
        case .flexible:
            let titleY = contentInsets.top / 2.0 + bounds.midY - titleSize.height / 2.0 - contentInsets.bottom / 2.0
            titleOrigin = CGPoint(x: bounds.minX + contentInsets.left,
                                  y: titleY)

            let indicatorY = contentInsets.top / 2.0 + bounds.midY - indicatorSize.height / 2.0
                + verticalDisplacement - contentInsets.bottom / 2.0
            indicatorOrigin = CGPoint(x: bounds.maxX - indicatorSize.width - contentInsets.right,
                                      y: indicatorY)
        }

        title?.frame = CGRect(origin: titleOrigin, size: titleSize)
        indicator?.frame = CGRect(origin: indicatorOrigin, size: indicatorSize)
    }

    open func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    // MARK: Activation

    open func activate(animated: Bool) {
        if animated {
            UIView.animate(withDuration: Constants.activationAnimationDuration) {
                self.indicator?.activate()
            }
        } else {
            indicator?.activate()
        }
    }

    open func deactivate(animated: Bool) {
        if animated {
            UIView.animate(withDuration: Constants.activationAnimationDuration) {
                self.indicator?.deactivate()
            }
        } else {
            indicator?.deactivate()
        }
    }

    // Actions

    @objc func actionOnTouchUpInside(sender: AnyObject) {
        if isActivated {
            deactivate(animated: true)
        } else {
            activate(animated: true)
        }

        sendActions(for: [.valueChanged])
    }

    override open var isHighlighted: Bool {
        didSet {
            updateDisplayState()
        }
    }

    private func updateDisplayState() {
        title?.alpha = isHighlighted ?  Constants.highlightedAlpha : 1.0
        indicator?.alpha = isHighlighted ? Constants.highlightedAlpha : 1.0
    }
}
