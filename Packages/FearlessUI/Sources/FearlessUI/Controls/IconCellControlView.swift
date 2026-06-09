/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
open class IconCellControlView: BackgroundedContentControl {

    public var separatorWidth: CGFloat = 1.0 {
        didSet {
            invalidateLayout()
        }
    }

    public var separatorColor: UIColor = .darkGray {
        didSet {
            setNeedsDisplay()
        }
    }

    public var imageWithTitleView: ImageWithTitleView? {
        return self.contentView as? ImageWithTitleView
    }

    public var roundedBackgroundView: RoundedView? {
        return self.backgroundView as? RoundedView
    }

    // MARK: Overriden initializers

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    open func configure() {
        self.backgroundColor = UIColor.clear

        if self.backgroundView == nil {
            self.backgroundView = RoundedView()
            self.backgroundView?.isUserInteractionEnabled = false
        }

        if self.contentView == nil {
            self.contentView = ImageWithTitleView()
            self.contentView?.isUserInteractionEnabled = false
        }
    }

    // MARK: Layout

    override open var intrinsicContentSize: CGSize {
        guard let currentContentView = contentView else { return CGSize.zero }

        var width = contentInsets.left + contentInsets.right
        var height = contentInsets.top + contentInsets.bottom

        let contentSize = currentContentView.intrinsicContentSize
        width += contentSize.width
        height += contentSize.height

        height += separatorWidth

        return CGSize(width: width, height: height)
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        backgroundView?.frame = bounds
        backgroundView?.frame.size.height -= separatorWidth

        guard let currentContentView = contentView else { return }

        let contentSize = currentContentView.intrinsicContentSize
        let contentX = contentInsets.left - contentInsets.right
        let contentY = CGFloat(Int(bounds.size.height / 2.0 - contentSize.height / 2.0
            + (contentInsets.top - contentInsets.bottom) / 2.0))

        currentContentView.frame = CGRect(origin: CGPoint(x: contentX, y: contentY), size: contentSize)
        currentContentView.frame.size.height -= separatorWidth
    }

    override open func draw(_ rect: CGRect) {
        super.draw(rect)

        if separatorWidth > 0.0 {
            let bezierPath = UIBezierPath()
            bezierPath.lineWidth = separatorWidth
            bezierPath.move(to: CGPoint(x: rect.minX, y: rect.maxY - separatorWidth / 2.0))
            bezierPath.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - separatorWidth / 2.0))
            separatorColor.setStroke()
            bezierPath.stroke()
        }
    }
}
