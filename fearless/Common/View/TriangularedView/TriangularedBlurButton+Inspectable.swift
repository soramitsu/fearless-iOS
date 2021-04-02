import UIKit
import SoraUI

extension TriangularedBlurButton {
    @IBInspectable
    private var _layoutType: UInt8 {
        get {
            imageWithTitleView!.layoutType.rawValue
        }

        set(newValue) {
            if let layoutType = ImageWithTitleView.LayoutType(rawValue: newValue) {
                imageWithTitleView!.layoutType = layoutType
            }
        }
    }

    @IBInspectable
    private var _title: String? {
        get {
            imageWithTitleView!.title
        }

        set(newValue) {
            imageWithTitleView!.title = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            imageWithTitleView!.titleColor
        }

        set(newValue) {
            imageWithTitleView!.titleColor = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _highlightedTitleColor: UIColor? {
        get {
            imageWithTitleView!.highlightedTitleColor
        }

        set(newValue) {
            imageWithTitleView!.highlightedTitleColor = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _iconImage: UIImage? {
        get {
            imageWithTitleView!.iconImage
        }

        set(newValue) {
            imageWithTitleView!.iconImage = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _highlightedIconImage: UIImage? {
        get {
            imageWithTitleView!.highlightedIconImage
        }

        set(newValue) {
            imageWithTitleView!.highlightedIconImage = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _iconTintColor: UIColor? {
        get {
            imageWithTitleView!.iconTintColor
        }

        set(newValue) {
            imageWithTitleView!.iconTintColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            imageWithTitleView!.titleFont?.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                imageWithTitleView?.titleFont = nil
                return
            }

            guard let pointSize = imageWithTitleView!.titleFont?.pointSize else {
                imageWithTitleView!.titleFont = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            imageWithTitleView!.titleFont = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            if let pointSize = imageWithTitleView!.titleFont?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }

        set(newValue) {
            guard let fontName = imageWithTitleView!.titleFont?.fontName else {
                imageWithTitleView!.titleFont = UIFont.systemFont(ofSize: newValue)
                return
            }

            imageWithTitleView!.titleFont = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _spacingBetweenItems: CGFloat {
        get {
            imageWithTitleView!.spacingBetweenLabelAndIcon
        }

        set(newValue) {
            imageWithTitleView!.spacingBetweenLabelAndIcon = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _contentOpacityWhenHighlighted: CGFloat {
        get {
            contentOpacityWhenHighlighted
        }

        set(newValue) {
            contentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _contentOpacityWhenDisabled: CGFloat {
        get {
            contentOpacityWhenDisabled
        }

        set(newValue) {
            contentOpacityWhenDisabled = newValue
        }
    }

    @IBInspectable
    private var _changesContentOpacityWhenHighlighted: Bool {
        get {
            changesContentOpacityWhenHighlighted
        }

        set(newValue) {
            changesContentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _displacementBetweenLabelAndIcon: CGFloat {
        get {
            imageWithTitleView!.displacementBetweenLabelAndIcon
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
