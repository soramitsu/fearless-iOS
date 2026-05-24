/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

extension ActionTitleControl {
    @IBInspectable
    private var _title: String? {
        get {
            return titleLabel.text
        }

        set(newValue) {
            titleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            return titleLabel.textColor
        }

        set(newValue) {
            titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _horizontalSpacing: CGFloat {
        get {
            return horizontalSpacing
        }

        set(newValue) {
            horizontalSpacing = newValue
        }
    }

    @IBInspectable
    private var _iconDisplacement: CGFloat {
        get {
            return iconDisplacement
        }

        set(newValue) {
            iconDisplacement = newValue
        }
    }

    @IBInspectable
    private var _activationAngle: CGFloat {
        get {
            return activationIconAngle * 180.0 / CGFloat.pi
        }

        set(newValue) {
            activationIconAngle = newValue * CGFloat.pi / 180.0
        }
    }

    @IBInspectable
    private var _identityAngle: CGFloat {
        get {
            return identityIconAngle * 180.0 / CGFloat.pi
        }

        set(newValue) {
            identityIconAngle = newValue * CGFloat.pi / 180.0
        }
    }

    @IBInspectable
    private var _iconColor: UIColor? {
        get {
            return imageView.tintColor
        }

        set(newValue) {
            imageView.tintColor = newValue
        }
    }

    @IBInspectable
    private var _icon: UIImage? {
        get {
            return imageView.image
        }

        set(newValue) {
            imageView.image = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                self.titleLabel.font = nil
                return
            }

            guard let pointSize = self.titleLabel.font?.pointSize else {
                self.titleLabel.font = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            self.titleLabel.font = UIFont(name: fontName, size: pointSize)

            self.invalidateLayout()
        }

        get {
            return self.titleLabel.font.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set(newValue) {
            guard let fontName = self.titleLabel.font?.fontName else {
                self.titleLabel.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            self.titleLabel.font = UIFont(name: fontName, size: newValue)

            self.invalidateLayout()
        }

        get {
            if let pointSize = self.titleLabel.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _minimumFontScale: CGFloat {
        set(newValue) {
            titleLabel.minimumScaleFactor = newValue
            invalidateLayout()
        }

        get {
            return titleLabel.minimumScaleFactor
        }
    }

    @IBInspectable
    private var _adjustsFontSizeToFitWidth: Bool {
        set(newValue) {
            titleLabel.adjustsFontSizeToFitWidth = newValue
            invalidateLayout()
        }

        get {
            return titleLabel.adjustsFontSizeToFitWidth
        }
    }

    @IBInspectable
    private var _layoutType: UInt {
        set(newValue) {
            guard let newType = LayoutType(rawValue: newValue) else {
                return
            }

            layoutType = newType
        }

        get {
            return layoutType.rawValue
        }
    }
}
