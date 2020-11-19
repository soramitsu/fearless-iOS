import UIKit
import SoraUI

extension TriangularedBlurButton {
    @IBInspectable
    private var _layoutType: UInt8 {
        get {
            return self.imageWithTitleView!.layoutType.rawValue
        }

        set(newValue) {
            if let layoutType = ImageWithTitleView.LayoutType(rawValue: newValue) {
                self.imageWithTitleView!.layoutType = layoutType
            }
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
    private var _iconTintColor: UIColor? {
        get {
            return imageWithTitleView!.iconTintColor
        }

        set(newValue) {
            imageWithTitleView!.iconTintColor = newValue
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
    private var _contentOpacityWhenDisabled: CGFloat {
        get {
            return contentOpacityWhenDisabled
        }

        set(newValue) {
            contentOpacityWhenDisabled = newValue
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

    @IBInspectable
    private var _cornerCut: UInt8 {
        get {
            triangularedBlurView!.cornerCut.rawValue
        }

        set {
            triangularedBlurView!.cornerCut = TriangularedCorners(rawValue: newValue)
        }
    }

    @IBInspectable
    private var _blurStyle: Int {
        get {
            triangularedBlurView?.blurStyle.rawValue ?? 0
        }

        set {
            if let newBlur = UIBlurEffect.Style(rawValue: newValue) {
                triangularedBlurView?.blurStyle = newBlur
            }
        }
    }

    @IBInspectable
    private var _overlayFillColor: UIColor {
        get {
            triangularedBlurView?.overlayView.fillColor ?? UIColor.black
        }

        set {
            triangularedBlurView?.overlayView.fillColor = newValue
            triangularedBlurView?.overlayView.highlightedFillColor = newValue
        }
    }
}
