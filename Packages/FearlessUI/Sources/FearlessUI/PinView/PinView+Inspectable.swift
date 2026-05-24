/**
* Copyright Soramitsu Co., Ltd. All Rights Reserved.
* SPDX-License-Identifier: GPL-3.0
*/

import UIKit

@IBDesignable
extension PinView {
    open override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()
        configure()
    }

    @IBInspectable
    private var _mode: Int8 {
        set(newValue) {
            if let mode = PinView.Mode(rawValue: newValue) {
                self.mode = mode
            }
        }

        get { return mode.rawValue }
    }

    @IBInspectable
    private var _verticalSpacing: CGFloat {
        set(newValue) {
            self.verticalSpacing = newValue
        }

        get { return self.verticalSpacing }
    }

    @IBInspectable
    private var _numberOfCharacters: Int {
        set(newValue) {
            characterFieldsView?.numberOfCharacters = newValue
            securedCharacterFieldsView?.numberOfCharacters = newValue
            invalidateLayout()
        }

        get {
            return activeFieldsView.numberOfCharacters
        }
    }

    @IBInspectable
    private var _fieldSize: CGSize {
        set(newValue) {
            characterFieldsView?.fieldSize = newValue
            securedCharacterFieldsView?.fieldSize = newValue
            invalidateLayout()
        }

        get {
            // swiftlint:disable:next force_cast
            return (activeFieldsView as! BaseCharacterFieldsView).fieldSize
        }
    }

    @IBInspectable
    private var _fieldSpacing: CGFloat {
        set(newValue) {
            characterFieldsView?.fieldSpacing = newValue
            securedCharacterFieldsView?.fieldSpacing = newValue
            invalidateLayout()
        }

        get {
            // swiftlint:disable:next force_cast
            return (activeFieldsView as! BaseCharacterFieldsView).fieldSpacing
        }
    }

    @IBInspectable
    private var _fieldFillColor: UIColor {
        set(newValue) {
            securedCharacterFieldsView?.fillColor = newValue
        }

        get {
            if let securedFieldsView = securedCharacterFieldsView {
                return securedFieldsView.fillColor
            }

            return UIColor.clear
        }
    }

    @IBInspectable
    private var _fieldStrokeColor: UIColor {
        set(newValue) {
            characterFieldsView?.fieldColor = newValue
            securedCharacterFieldsView?.strokeColor = newValue
        }

        get {
            if let charactersFieldsView = characterFieldsView {
                return charactersFieldsView.fieldColor
            }

            if let securedFieldsView = securedCharacterFieldsView {
                return securedFieldsView.strokeColor
            }

            return UIColor.clear
        }
    }

    @IBInspectable
    private var _fieldStrokeWidth: CGFloat {
        set(newValue) {
            characterFieldsView?.fieldStrokeWidth = newValue
        }

        get {
            if let characterFieldsView = characterFieldsView {
                return characterFieldsView.fieldStrokeWidth
            }

            return 0.0
        }
    }

    @IBInspectable
    private var _securedStrokeWidth: CGFloat {
        set(newValue) {
            securedCharacterFieldsView?.strokeWidth = newValue
        }

        get {
            if let securedFieldsView = securedCharacterFieldsView {
                return securedFieldsView.strokeWidth
            }

            return 0.0
        }
    }

    @IBInspectable
    private var _securedFieldRadius: CGFloat {
        set(newValue) {
            securedCharacterFieldsView?.fieldRadius = newValue
        }

        get {
            if let securedFieldsView = securedCharacterFieldsView {
                return securedFieldsView.fieldRadius
            }

            return 0.0
        }
    }

    @IBInspectable
    private var _fieldFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                return
            }

            guard let pointSize = characterFieldsView?.fieldFont.pointSize else {
                if let font = UIFont(name: fontName, size: UIFont.labelFontSize) {
                    characterFieldsView?.fieldFont = font
                    invalidateLayout()
                }
                return
            }

            if let font = UIFont(name: fontName, size: pointSize) {
                characterFieldsView?.fieldFont = font
            }

            self.invalidateLayout()
        }

        get {
            return characterFieldsView?.fieldFont.fontName
        }
    }

    @IBInspectable
    private var _fieldFontSize: CGFloat {
        set(newValue) {
            guard let fontName = characterFieldsView?.fieldFont.fontName else {
                characterFieldsView?.fieldFont = UIFont.systemFont(ofSize: newValue)
                invalidateLayout()
                return
            }

            if let font = UIFont(name: fontName, size: newValue) {
                characterFieldsView?.fieldFont = font
            }

            self.invalidateLayout()
        }

        get {
            if let pointSize = characterFieldsView?.fieldFont.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _numpadFillColor: UIColor? {
        set(newValue) {
            numpadView?.fillColor = newValue
        }

        get { return numpadView?.fillColor }
    }

    @IBInspectable
    private var _numpadHighlightedFillColor: UIColor? {
        set(newValue) {
            numpadView?.highlightedFillColor = newValue
        }

        get { return numpadView?.highlightedFillColor }
    }

    @IBInspectable
    private var _numpadTitleColor: UIColor? {
        set(newValue) {
            numpadView?.titleColor = newValue
        }

        get { return numpadView?.titleColor }
    }

    @IBInspectable
    private var _numpadHighlightedTitleColor: UIColor? {
        set(newValue) {
            numpadView?.highlightedTitleColor = newValue
        }

        get { return numpadView?.highlightedTitleColor }
    }

    /// By default the same as for `RoundedButton`
    @IBInspectable
    private var _numpadShadowOpacity: Float {
        set(newValue) {
            numpadView?.shadowOpacity = newValue
        }

        get { return numpadView?.shadowOpacity ?? 0.0 }
    }

    @IBInspectable
    private var _numpadShadowColor: UIColor? {
        set(newValue) {
            numpadView?.shadowColor = newValue
        }

        get { return numpadView?.shadowColor }
    }

    @IBInspectable
    private var shadowRadius: CGFloat {
        set(newValue) {
            numpadView?.shadowRadius = newValue
        }

        get { return numpadView?.shadowRadius ?? 0.0 }
    }

    @IBInspectable
    private var shadowOffset: CGSize {
        set(newValue) {
            numpadView?.shadowOffset = newValue
        }

        get { return numpadView?.shadowOffset ?? CGSize.zero }
    }

    @IBInspectable
    private var _numpadFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                return
            }

            guard let pointSize = numpadView?.titleFont?.pointSize else {
                numpadView?.titleFont = UIFont(name: fontName, size: UIFont.labelFontSize)
                invalidateLayout()
                return
            }

            numpadView?.titleFont = UIFont(name: fontName, size: pointSize)

            self.invalidateLayout()
        }

        get {
            return numpadView?.titleFont?.fontName
        }
    }

    @IBInspectable
    private var _numpadFontSize: CGFloat {
        set(newValue) {
            guard let fontName = numpadView?.titleFont?.fontName else {
                numpadView?.titleFont = UIFont.systemFont(ofSize: newValue)
                invalidateLayout()
                return
            }

            numpadView?.titleFont = UIFont(name: fontName, size: newValue)

            self.invalidateLayout()
        }

        get {
            if let pointSize = numpadView?.titleFont?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _numpadBackspaceIcon: UIImage? {
        set(newValue) {
            numpadView?.backspaceIcon = newValue
        }

        get { return numpadView?.backspaceIcon }
    }

    @IBInspectable
    private var _numpadHighlightedBackspaceIcon: UIImage? {
        set(newValue) {
            numpadView?.backspaceHighlightedIcon = newValue
        }

        get { return numpadView?.backspaceHighlightedIcon }
    }

    @IBInspectable
    private var _numpadAccessoryIcon: UIImage? {
        set(newValue) {
            numpadView?.accessoryIcon = newValue
        }

        get { return numpadView?.accessoryIcon }
    }

    @IBInspectable
    private var _numpadHighlightedAccessoryIcon: UIImage? {
        set(newValue) {
            numpadView?.accessoryHighlightedIcon = newValue
        }

        get { return numpadView?.accessoryHighlightedIcon }
    }

    @IBInspectable
    private var _numpadSupportsAccessoryControl: Bool {
        set(newValue) {
            numpadView?.supportsAccessoryControl = newValue
        }

        get {
            return numpadView?.supportsAccessoryControl ?? false
        }
    }

    @IBInspectable
    private var _numpadRadius: CGFloat {
        set(newValue) {
            numpadView?.keyRadius = newValue
        }

        get {
            if let numpadView = numpadView {
                return numpadView.keyRadius
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _numpadVerticalSpacing: CGFloat {
        set(newValue) {
            numpadView?.verticalSpacing = newValue
        }

        get {
            if let numpadView = numpadView {
                return numpadView.verticalSpacing
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _numpadHorizontalSpacing: CGFloat {
        set(newValue) {
            numpadView?.horizontalSpacing = newValue
        }

        get {
            if let numpadView = numpadView {
                return numpadView.horizontalSpacing
            } else {
                return 0.0
            }
        }
    }
}
