import UIKit

@IBDesignable
extension DetailsTriangularedView {
    @IBInspectable
    var backgroundSideLength: CGFloat {
        get {
            triangularedBackgroundView!.sideLength
        }

        set {
            triangularedBackgroundView?.sideLength = newValue
        }
    }

    @IBInspectable
    var fillColor: UIColor {
        get {
            triangularedBackgroundView!.fillColor
        }

        set {
            triangularedBackgroundView!.fillColor = newValue
        }
    }

    @IBInspectable
    var highlightedFillColor: UIColor {
        get {
            triangularedBackgroundView!.highlightedFillColor
        }

        set {
            triangularedBackgroundView!.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    var strokeColor: UIColor {
        get {
            triangularedBackgroundView!.strokeColor
        }

        set {
            triangularedBackgroundView!.strokeColor = newValue
        }
    }

    @IBInspectable
    var highlightedStrokeColor: UIColor {
        get {
            triangularedBackgroundView!.highlightedStrokeColor
        }

        set {
            triangularedBackgroundView!.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    var title: String? {
        get {
            titleLabel.text
        }

        set {
            titleLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var subtitle: String? {
        get {
            subtitleLabel?.text
        }

        set {
            subtitleLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var titleColor: UIColor? {
        get {
            titleLabel.textColor
        }

        set {
            titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    var highlightedTitleColor: UIColor? {
        get {
            titleLabel.highlightedTextColor
        }

        set {
            titleLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    var subtitleColor: UIColor? {
        get {
            subtitleLabel?.textColor
        }

        set {
            subtitleLabel?.textColor = newValue
        }
    }

    @IBInspectable
    var highlightedSubtitleColor: UIColor? {
        get {
            subtitleLabel?.highlightedTextColor
        }

        set {
            subtitleLabel?.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            titleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                titleLabel.font = nil
                return
            }

            let pointSize = titleLabel.font.pointSize

            titleLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            titleLabel.font.pointSize
        }

        set(newValue) {
            let fontName = titleLabel.font.fontName

            titleLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        get {
            subtitleLabel?.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                subtitleLabel?.font = nil
                return
            }

            let pointSize = subtitleLabel?.font.pointSize ?? UIFont.labelFontSize

            subtitleLabel?.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        get {
            subtitleLabel?.font.pointSize ?? 0.0
        }

        set(newValue) {
            guard let fontName = subtitleLabel?.font.fontName else {
                return
            }

            subtitleLabel?.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var iconImage: UIImage? {
        get {
            iconView.image
        }

        set {
            iconView.image = newValue
        }
    }

    @IBInspectable
    var actionImage: UIImage? {
        get {
            actionView.image
        }

        set {
            actionView.image = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var actionTintColor: UIColor? {
        get {
            actionView.tintColor
        }

        set {
            actionView.tintColor = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            triangularedBackgroundView?.strokeWidth ?? 0.0
        }

        set {
            triangularedBackgroundView?.strokeWidth = newValue
        }
    }

    @IBInspectable
    private var _iconRadius: CGFloat {
        get {
            iconRadius
        }

        set {
            iconRadius = newValue
        }
    }

    @IBInspectable
    private var _horizontalSpacing: CGFloat {
        get {
            horizontalSpacing
        }

        set {
            horizontalSpacing = newValue
        }
    }

    @IBInspectable
    private var _layout: UInt8 {
        get {
            switch layout {
            case .largeIconTitleSubtitle:
                return 0
            case .smallIconTitleSubtitle:
                return 1
            case .singleTitle:
                return 2
            }
        }

        set {
            switch newValue {
            case 0:
                layout = .largeIconTitleSubtitle
            case 1:
                layout = .smallIconTitleSubtitle
            default:
                layout = .singleTitle
            }
        }
    }
}
