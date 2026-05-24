/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

extension GradientButton {
    @IBInspectable
    private var _startColor: UIColor {
        set(newValue) {
            gradientBackgroundView!.startColor = newValue
        }

        get {
            return gradientBackgroundView!.startColor
        }
    }

    @IBInspectable
    private var _endColor: UIColor {
        set(newValue) {
            gradientBackgroundView!.endColor = newValue
        }

        get {
            return gradientBackgroundView!.endColor
        }
    }

    @IBInspectable
    private var _startPoint: CGPoint {
        set(newValue) {
            gradientBackgroundView!.startPoint = newValue
        }

        get {
            return gradientBackgroundView!.startPoint
        }
    }

    @IBInspectable
    private var _endPoint: CGPoint {
        set(newValue) {
            gradientBackgroundView!.endPoint = newValue
        }

        get {
            return gradientBackgroundView!.endPoint
        }
    }

    @IBInspectable
    private var _transitionLocation: Float {
        set(newValue) {
            gradientBackgroundView!.transitionLocation = newValue
        }

        get {
            return gradientBackgroundView!.transitionLocation
        }
    }

    @IBInspectable
    private var _title: String? {
        get {
            return self.imageWithTitleView!.title
        }

        set(newValue) {
            self.imageWithTitleView!.title = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _iconImage: UIImage? {
        get {
            return self.imageWithTitleView!.iconImage
        }

        set(newValue) {
            self.imageWithTitleView!.iconImage = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _highlightedIconImage: UIImage? {
        get {
            return self.imageWithTitleView!.highlightedIconImage
        }

        set(newValue) {
            self.imageWithTitleView!.highlightedIconImage = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            return self.imageWithTitleView!.titleColor
        }

        set(newValue) {
            self.imageWithTitleView!.titleColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _highlightedTitleColor: UIColor? {
        get {
            return self.imageWithTitleView!.highlightedTitleColor
        }

        set(newValue) {
            self.imageWithTitleView!.highlightedTitleColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                self.imageWithTitleView?.titleFont = nil
                return
            }

            guard let pointSize = self.imageWithTitleView!.titleFont?.pointSize else {
                self.imageWithTitleView!.titleFont = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            self.imageWithTitleView!.titleFont = UIFont(name: fontName, size: pointSize)

            self.invalidateLayout()
        }

        get {
            return self.imageWithTitleView!.titleFont?.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set(newValue) {
            guard let fontName = self.imageWithTitleView!.titleFont?.fontName else {
                self.imageWithTitleView!.titleFont = UIFont.systemFont(ofSize: newValue)
                return
            }

            self.imageWithTitleView!.titleFont = UIFont(name: fontName, size: newValue)

            self.invalidateLayout()
        }

        get {
            if let pointSize = self.imageWithTitleView!.titleFont?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _cornerRadius: CGFloat {
        get {
            return self.gradientBackgroundView!.cornerRadius
        }

        set(newValue) {
            self.gradientBackgroundView!.cornerRadius = newValue
        }
    }

    @IBInspectable
    private var _spacingBetweenItems: CGFloat {
        get {
            return self.imageWithTitleView!.spacingBetweenLabelAndIcon
        }

        set(newValue) {
            self.imageWithTitleView!.spacingBetweenLabelAndIcon = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _contentOpacityWhenHighlighted: CGFloat {
        get {
            return contentOpacityWhenHighlighted
        }

        set(newValue) {
            contentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _changesContentOpacityWhenHighlighted: Bool {
        get {
            return changesContentOpacityWhenHighlighted
        }

        set(newValue) {
            changesContentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _displacementBetweenLabelAndIcon: CGFloat {
        get {
            return imageWithTitleView!.displacementBetweenLabelAndIcon
        }

        set(newValue) {
            imageWithTitleView!.displacementBetweenLabelAndIcon = newValue
        }
    }
}
