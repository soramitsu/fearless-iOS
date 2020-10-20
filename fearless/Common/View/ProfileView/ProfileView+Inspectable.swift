import UIKit

extension ProfileView {
    @IBInspectable
    private var _fillColor: UIColor {
        get {
            return backgroundView.fillColor
        }

        set(newValue) {
            backgroundView.fillColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedFillColor: UIColor {
        get {
            return backgroundView.highlightedFillColor
        }

        set(newValue) {
            backgroundView.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    private var _strokeColor: UIColor {
        get {
            return backgroundView.strokeColor
        }

        set(newValue) {
            backgroundView.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedStrokeColor: UIColor {
        get {
            return backgroundView.highlightedStrokeColor
        }

        set(newValue) {
            backgroundView.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    private var _strokeWidth: CGFloat {
        get {
            return backgroundView.strokeWidth
        }

        set(newValue) {
            backgroundView.strokeWidth = newValue
        }
    }

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
    private var _highlightedTitleColor: UIColor? {
        get {
            return titleLabel.highlightedTextColor
        }

        set(newValue) {
            titleLabel.highlightedTextColor = newValue
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
        }

        get {
            return titleLabel.font.pointSize
        }
    }

    @IBInspectable
    private var _subtitle: String? {
        get {
            return subtitleLabel.text
        }

        set(newValue) {
            subtitleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _subtitleColor: UIColor? {
        get {
            return subtitleLabel.textColor
        }

        set(newValue) {
            subtitleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedSubtitleColor: UIColor? {
        get {
            return subtitleLabel.highlightedTextColor
        }

        set(newValue) {
            subtitleLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                subtitleLabel.font = nil
                return
            }

            let pointSize = subtitleLabel.font.pointSize
            subtitleLabel.font = UIFont(name: fontName, size: pointSize)
        }

        get {
            return subtitleLabel.font.fontName
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        set(newValue) {
            let fontName = subtitleLabel.font.fontName
            subtitleLabel.font = UIFont(name: fontName, size: newValue)
        }

        get {
            return subtitleLabel.font.pointSize
        }
    }

    @IBInspectable
    private var _shadowColor: UIColor {
        get {
            return backgroundView.shadowColor
        }

        set(newValue) {
            backgroundView.shadowColor = newValue
        }
    }

    @IBInspectable
    private var _shadowOffset: CGSize {
        get {
            return backgroundView.shadowOffset
        }

        set(newValue) {
            backgroundView.shadowOffset = newValue
        }
    }

    @IBInspectable
    private var _shadowRadius: CGFloat {
        get {
            return backgroundView.shadowRadius
        }

        set(newValue) {
            backgroundView.shadowRadius = newValue
        }
    }

    @IBInspectable
    private var _shadowOpacity: Float {
        get {
            return backgroundView.shadowOpacity
        }

        set(newValue) {
            backgroundView.shadowOpacity = newValue
        }
    }

    @IBInspectable
    private var _contentOpacityWhenHighlighted: CGFloat {
        get {
            return contentControl.contentOpacityWhenHighlighted
        }

        set(newValue) {
            contentControl.contentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _changesContentOpacityWhenHighlighted: Bool {
        get {
            return contentControl.changesContentOpacityWhenHighlighted
        }

        set(newValue) {
            contentControl.changesContentOpacityWhenHighlighted = newValue
        }
    }

    @IBInspectable
    private var _topInset: CGFloat {
        get {
            contentInsets.top
        }

        set {
            var newInsets = contentInsets
            newInsets.top = newValue
            contentInsets = newInsets
        }
    }

    @IBInspectable
    private var _bottomInset: CGFloat {
        get {
            contentInsets.bottom
        }

        set {
            var newInsets = contentInsets
            newInsets.bottom = newValue
            contentInsets = newInsets
        }
    }

    @IBInspectable
    private var _leftInset: CGFloat {
        get {
            contentInsets.left
        }

        set {
            var newInsets = contentInsets
            newInsets.left = newValue
            contentInsets = newInsets
        }
    }

    @IBInspectable
    private var _rightInset: CGFloat {
        get {
            contentInsets.right
        }

        set {
            var newInsets = contentInsets
            newInsets.right = newValue
            contentInsets = newInsets
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
    private var _iconRadius: CGFloat {
        get {
            iconRadius
        }

        set {
            iconRadius = newValue
        }
    }

    @IBInspectable
    private var _iconFillColor: UIColor {
        get {
            iconView.fillColor
        }

        set {
            iconView.fillColor = newValue
        }
    }

    @IBInspectable
    private var _copyIcon: UIImage? {
        get {
            copyButton.imageWithTitleView?.iconImage
        }

        set {
            copyButton.imageWithTitleView?.iconImage = newValue
            copyButton.invalidateLayout()
            setNeedsLayout()
        }
    }
}
