/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

open class ImageActionIndicator: ActionControlIndicatorView {
    public var isActivated: Bool = false

    public var image: UIImage? {
        get {
            imageView.image
        }

        set {
            imageView.image = newValue
        }
    }

    private var imageView: UIImageView = UIImageView()

    open var activationIconAngle: CGFloat = -CGFloat.pi {
        didSet {
            if isActivated {
                imageView.transform = CGAffineTransform(rotationAngle: activationIconAngle)
            }
        }
    }

    open var identityIconAngle: CGFloat = 0.0 {
        didSet {
            if !isActivated {
                imageView.transform = CGAffineTransform(rotationAngle: identityIconAngle)
            }
        }
    }

    override open var intrinsicContentSize: CGSize { imageView.intrinsicContentSize }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)

        configure()
    }

    private func configure() {
        if imageView.superview == nil {
            addSubview(imageView)

            imageView.backgroundColor = .clear
            imageView.frame = CGRect(origin: .zero, size: frame.size)
            imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        }
    }

    public func activate() {
        isActivated = true

        // apply half path first to enforce right rotation direction
        imageView.transform = CGAffineTransform(rotationAngle: self.activationIconAngle / 2.0)
        imageView.transform = CGAffineTransform(rotationAngle: self.activationIconAngle)
    }

    public func deactivate() {
        isActivated = false

        imageView.transform = CGAffineTransform(rotationAngle: identityIconAngle)
    }
}

@IBDesignable
open class ActionTitleControl: BaseActionControl {

    public var imageView: ImageActionIndicator! {
        indicator as? ImageActionIndicator
    }

    public var titleLabel: UILabel! {
        title as? UILabel
    }

    public var iconDisplacement: CGFloat {
        get {
            verticalDisplacement
        }

        set {
            verticalDisplacement = newValue
        }
    }

    public var activationIconAngle: CGFloat {
        get {
            imageView.activationIconAngle
        }

        set {
            imageView.activationIconAngle = newValue
        }
    }

    public var identityIconAngle: CGFloat {
        get {
            imageView.identityIconAngle
        }

        set {
            imageView.identityIconAngle = newValue
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
        if indicator == nil {
            self.indicator = ImageActionIndicator()
            self.indicator?.backgroundColor = .clear
        }

        if title == nil {
            self.title = UILabel()
            self.backgroundColor = .clear
        }
    }
}
