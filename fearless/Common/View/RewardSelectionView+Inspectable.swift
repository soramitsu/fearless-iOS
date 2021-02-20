import UIKit

@IBDesignable
extension RewardSelectionView {
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
            iconView.tintColor = newValue
            triangularedBackgroundView!.highlightedStrokeColor = newValue
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
    var titleColor: UIColor? {
        get {
            return titleLabel.textColor
        }

        set {
            titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            return titleLabel.font.fontName
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
    var earningTitle: String? {
        get {
            return earningsTitleLabel?.text
        }

        set {
            earningsTitleLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _earningTitleFontName: String? {
        get {
            return earningsTitleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                earningsTitleLabel.font = nil
                return
            }

            let pointSize = earningsTitleLabel.font.pointSize

            earningsTitleLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _earningTitleFontSize: CGFloat {
        get {
            earningsTitleLabel.font.pointSize
        }

        set(newValue) {
            let fontName = earningsTitleLabel.font.fontName

            earningsTitleLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var earningTitleColor: UIColor? {
        get {
            return earningsTitleLabel.textColor
        }

        set {
            earningsTitleLabel.textColor = newValue
        }
    }

    @IBInspectable
    var subtitle: String? {
        get {
            return subtitleLabel.text
        }

        set {
            subtitleLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        get {
            return subtitleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                subtitleLabel.font = nil
                return
            }

            let pointSize = subtitleLabel.font.pointSize

            subtitleLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        get {
            subtitleLabel.font.pointSize
        }

        set(newValue) {
            let fontName = subtitleLabel.font.fontName

            subtitleLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var subtitleColor: UIColor? {
        get {
            return subtitleLabel.textColor
        }

        set {
            subtitleLabel.textColor = newValue
        }
    }

    @IBInspectable
    var earningsSubtitle: String? {
        get {
            return earningsSubtitleLabel.text
        }

        set {
            earningsSubtitleLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _earningsSubtitleFontName: String? {
        get {
            return earningsSubtitleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                earningsSubtitleLabel.font = nil
                return
            }

            let pointSize = earningsSubtitleLabel.font.pointSize

            earningsSubtitleLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _earningsSubtitleFontSize: CGFloat {
        get {
            earningsSubtitleLabel.font.pointSize
        }

        set(newValue) {
            let fontName = earningsSubtitleLabel.font.fontName

            earningsSubtitleLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var earningsSubtitleColor: UIColor? {
        get {
            return earningsSubtitleLabel.textColor
        }

        set {
            earningsSubtitleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _isSelected: Bool {
        get {
            isSelected
        }

        set {
            isSelected = newValue
        }
    }

    @IBInspectable
    private var _selectionIcon: UIImage? {
        get {
            iconView.image
        }

        set {
            iconView.image = newValue
        }
    }
}
