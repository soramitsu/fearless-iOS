import Foundation
import SoraUI

/// Extension of the TriangularedButton to support design through Interface Builder
extension TriangularedButton {
    @IBInspectable
    private var _fillColor: UIColor {
        get {
            triangularedView!.fillColor
        }

        set(newValue) {
            triangularedView!.fillColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedFillColor: UIColor {
        get {
            triangularedView!.highlightedFillColor
        }

        set(newValue) {
            triangularedView!.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    private var _strokeColor: UIColor {
        get {
            triangularedView!.strokeColor
        }

        set(newValue) {
            triangularedView!.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedStrokeColor: UIColor {
        get {
            triangularedView!.highlightedStrokeColor
        }

        set(newValue) {
            triangularedView!.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    private var _strokeWidth: CGFloat {
        get {
            triangularedView!.strokeWidth
        }

        set(newValue) {
            triangularedView!.strokeWidth = newValue
        }
    }

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
    private var _shadowColor: UIColor {
        get {
            triangularedView!.shadowColor
        }

        set(newValue) {
            triangularedView!.shadowColor = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _shadowOffset: CGSize {
        get {
            triangularedView!.shadowOffset
        }

        set(newValue) {
            triangularedView!.shadowOffset = newValue
        }
    }

    @IBInspectable
    private var _shadowRadius: CGFloat {
        get {
            triangularedView!.shadowRadius
        }

        set(newValue) {
            triangularedView!.shadowRadius = newValue
        }
    }

    @IBInspectable
    private var _shadowOpacity: Float {
        get {
            triangularedView!.shadowOpacity
        }

        set(newValue) {
            triangularedView!.shadowOpacity = newValue
        }
    }

    @IBInspectable
    private var _sideLength: CGFloat {
        get {
            triangularedView!.sideLength
        }

        set(newValue) {
            triangularedView!.sideLength = newValue
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
            triangularedView!.cornerCut.rawValue
        }

        set {
            triangularedView!.cornerCut = TriangularedCorners(rawValue: newValue)
        }
    }
}
