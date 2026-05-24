/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
open class EmptyStateView: UIView {
    public enum TrimStrategy {
        case none
        case hideTitle
    }

    @IBInspectable
    open var image: UIImage? {
        get {
            return imageView.image
        }

        set {
            imageView.image = newValue

            setNeedsLayout()
        }
    }

    @IBInspectable
    open var title: String? {
        get {
            return titleLabel.text
        }

        set {
            titleLabel.text = newValue

            setNeedsLayout()
        }
    }

    @IBInspectable
    open var titleColor: UIColor {
        get {
            return titleLabel.textColor
        }

        set {
            titleLabel.textColor = newValue
        }
    }

    open var titleFont: UIFont {
        get {
            return titleLabel.font
        }

        set {
            titleLabel.font = newValue

            setNeedsLayout()
        }
    }

    @IBInspectable
    open var verticalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    open var trimStrategy: TrimStrategy = .none {
        didSet {
            setNeedsLayout()
        }
    }

    private weak var imageView: UIImageView!
    private weak var titleLabel: UILabel!

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        configure()
    }

    override open func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()
    }

    private func configure() {
        if imageView == nil {
            configureImageView()
        }

        if titleLabel == nil {
            configureTitleLabel()
        }
    }

    private func configureImageView() {
        let imageView = UIImageView()
        addSubview(imageView)

        self.imageView = imageView
    }

    private func configureTitleLabel() {
        let titleLabel = UILabel()
        titleLabel.numberOfLines = 0
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = .clear
        addSubview(titleLabel)

        self.titleLabel = titleLabel
    }

    override open func layoutSubviews() {
        super.layoutSubviews()

        let layoutSize = bounds.size

        let titleSize = titleLabel.sizeThatFits(CGSize(width: layoutSize.width,
                                                       height: layoutSize.height / 2.0 - verticalSpacing / 2.0))
        var imageSize = image?.size ?? .zero

        if imageSize.width > 0.0, imageSize.width > layoutSize.width {
            imageSize.height *= layoutSize.width / imageSize.width
            imageSize.width = layoutSize.width
        }

        let expectedHeight = layoutSize.height / 2.0 - verticalSpacing / 2.0

        if titleSize.height <= expectedHeight, imageSize.height <= expectedHeight {
            layoutTitleWithImage(with: layoutSize,
                                 titleSize: titleSize,
                                 imageSize: imageSize)
            return
        }

        switch trimStrategy {
        case .none:
            layoutTitleWithImage(with: layoutSize,
                                 titleSize: titleSize,
                                 imageSize: imageSize)
        case .hideTitle:
            layoutImage(with: layoutSize,
                        imageSize: imageSize)
        }
    }

    private func layoutTitleWithImage(with layoutSize: CGSize, titleSize: CGSize, imageSize: CGSize) {
        let expectedHeight = layoutSize.height / 2.0 - verticalSpacing / 2.0

        if imageSize.height <= expectedHeight {
            let imageOrigin = CGPoint(x: bounds.midX - imageSize.width / 2.0,
                                      y: bounds.midY - verticalSpacing / 2.0 - imageSize.height)
            imageView.frame = CGRect(origin: imageOrigin, size: imageSize)

            let titleOrigin = CGPoint(x: bounds.midX - titleSize.width / 2.0,
                                      y: bounds.midY + verticalSpacing / 2.0)
            titleLabel.frame = CGRect(origin: titleOrigin, size: titleSize)
        } else {
            let imageOrigin = CGPoint(x: bounds.midX - imageSize.width / 2.0, y: 0.0)
            imageView.frame = CGRect(origin: imageOrigin, size: imageSize)

            let titleOrigin = CGPoint(x: bounds.midX - titleSize.width / 2.0, y: imageView.frame.maxY + verticalSpacing)

            let newTitleHeight = min(titleSize.height, layoutSize.height - imageView.frame.maxY - verticalSpacing)
            let newTitleSize = CGSize(width: titleSize.width,
                                      height: newTitleHeight)
            titleLabel.frame = CGRect(origin: titleOrigin, size: newTitleSize)
        }
    }

    private func layoutImage(with layoutSize: CGSize, imageSize: CGSize) {
        imageView.frame = CGRect(x: bounds.midX - imageSize.width / 2.0,
                                 y: bounds.midY - imageSize.height / 2.0,
                                 width: imageSize.width,
                                 height: imageSize.height)
        titleLabel.frame = .zero
    }
}
