import UIKit
import Foundation

extension AnimatedTextField {
    @IBInspectable
    private var _titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                return
            }

            let pointSize = self.titleFont.pointSize

            if let font = UIFont(name: fontName, size: pointSize) {
                self.titleFont = font
                setNeedsLayout()
            }
        }

        get {
            titleFont.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set(newValue) {
            let fontName = self.titleFont.fontName

            if let font = UIFont(name: fontName, size: newValue) {
                self.titleFont = font
                setNeedsLayout()
            }
        }

        get {
            titleFont.pointSize
        }
    }

    @IBInspectable
    private var _placeholderFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                return
            }

            let pointSize = self.placeholderFont.pointSize

            if let font = UIFont(name: fontName, size: pointSize) {
                self.placeholderFont = font
                setNeedsLayout()
            }
        }

        get {
            placeholderFont.fontName
        }
    }

    @IBInspectable
    private var _placeholderFontSize: CGFloat {
        set(newValue) {
            let fontName = self.placeholderFont.fontName

            if let font = UIFont(name: fontName, size: newValue) {
                self.placeholderFont = font
                setNeedsLayout()
            }
        }

        get {
            placeholderFont.pointSize
        }
    }

    @IBInspectable
    private var _textFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                return
            }

            guard let pointSize = self.textFont?.pointSize else {
                self.textFont = UIFont(name: fontName, size: UIFont.labelFontSize)
                return
            }

            self.textFont = UIFont(name: fontName, size: pointSize)
            setNeedsLayout()
        }

        get {
            textFont?.fontName
        }
    }

    @IBInspectable
    private var _textFontSize: CGFloat {
        set(newValue) {
            guard let fontName = self.textFont?.fontName else {
                self.textFont = nil
                return
            }

            self.textFont = UIFont(name: fontName, size: newValue)
            setNeedsLayout()
        }

        get {
            textFont?.pointSize ?? 0.0
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
