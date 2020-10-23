import UIKit

@IBDesignable
extension DetailsTriangularedView {
    @IBInspectable
    var fillColor: UIColor {
        get {
            backgroundView.fillColor
        }

        set {
            backgroundView.fillColor = newValue
        }
    }

    @IBInspectable
    var highlightedFillColor: UIColor {
        get {
            backgroundView.highlightedFillColor
        }

        set {
            backgroundView.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    var strokeColor: UIColor {
        get {
            backgroundView.strokeColor
        }

        set {
            backgroundView.strokeColor = newValue
        }
    }

    @IBInspectable
    var highlightedStrokeColor: UIColor {
        get {
            backgroundView.highlightedStrokeColor
        }

        set {
            backgroundView.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    var title: String? {
        get {
            return titleLabel.text
        }

        set {
            titleLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var subtitle: String? {
        get {
            return subtitleLabel?.text
        }

        set {
            subtitleLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var titleColor: UIColor? {
        get {
            return titleLabel.textColor
        }

        set {
            titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    var highlightedTitleColor: UIColor? {
        get {
            return titleLabel.highlightedTextColor
        }

        set {
            titleLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    var subtitleColor: UIColor? {
        get {
            return subtitleLabel?.textColor
        }

        set {
            subtitleLabel?.textColor = newValue
        }
    }

    @IBInspectable
    var highlightedSubtitleColor: UIColor? {
        get {
            return subtitleLabel?.highlightedTextColor
        }

        set {
            subtitleLabel?.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                titleLabel.font = nil
                return
            }

            let pointSize = titleLabel.font.pointSize

            titleLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }

        get {
            return titleLabel.font.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set(newValue) {
            let fontName = titleLabel.font.fontName

            titleLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }

        get {
            titleLabel.font.pointSize
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                titleLabel.font = nil
                return
            }

            let pointSize = subtitleLabel?.font.pointSize ?? UIFont.labelFontSize

            subtitleLabel?.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }

        get {
            return titleLabel.font.fontName
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        set(newValue) {
            guard let fontName = subtitleLabel?.font.fontName else {
                return
            }

            subtitleLabel?.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }

        get {
            subtitleLabel?.font.pointSize ?? 0.0
        }
    }

    @IBInspectable
    var iconImage: UIImage? {
        get {
            return iconView.image
        }

        set {
            iconView.image = newValue
        }
    }

    @IBInspectable
    var actionImage: UIImage? {
        get {
            return actionButton.imageWithTitleView?.iconImage
        }

        set {
            actionButton.imageWithTitleView?.iconImage = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var actionTintColor: UIColor? {
        get {
            return actionButton.imageWithTitleView?.tintColor
        }

        set {
            actionButton.imageWithTitleView?.tintColor = newValue
        }
    }

    @IBInspectable
    var borderWidth: CGFloat {
        get {
            backgroundView.strokeWidth
        }

        set {
            backgroundView.strokeWidth = newValue
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
            return self.contentInsets.left
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
            return self.contentInsets.bottom
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
            return self.contentInsets.right
        }
    }
}
