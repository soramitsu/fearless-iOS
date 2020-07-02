import UIKit

extension ProfileButton {
    @IBInspectable
    private var _fillColor: UIColor {
        get {
            return self.roundedBackgroundView!.fillColor
        }

        set(newValue) {
            self.roundedBackgroundView!.fillColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedFillColor: UIColor {
        get {
            return self.roundedBackgroundView!.highlightedFillColor
        }

        set(newValue) {
            self.roundedBackgroundView!.highlightedFillColor = newValue
        }
    }

    @IBInspectable
    private var _strokeColor: UIColor {
        get {
            return self.roundedBackgroundView!.strokeColor
        }

        set(newValue) {
            self.roundedBackgroundView!.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedStrokeColor: UIColor {
        get {
            return self.roundedBackgroundView!.highlightedStrokeColor
        }

        set(newValue) {
            self.roundedBackgroundView!.highlightedStrokeColor = newValue
        }
    }

    @IBInspectable
    private var _strokeWidth: CGFloat {
        get {
            return self.roundedBackgroundView!.strokeWidth
        }

        set(newValue) {
            self.roundedBackgroundView!.strokeWidth = newValue
        }
    }

    @IBInspectable
    private var _title: String? {
        get {
            return self.titleLabel.text
        }

        set(newValue) {
            self.titleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            return self.titleLabel.textColor
        }

        set(newValue) {
            self.titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedTitleColor: UIColor? {
        get {
            return self.titleLabel.highlightedTextColor
        }

        set(newValue) {
            self.titleLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                self.titleLabel.font = nil
                return
            }

            let pointSize = self.titleLabel.font.pointSize
            self.titleLabel.font = UIFont(name: fontName, size: pointSize)
        }

        get {
            return self.titleLabel.font.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set(newValue) {
            let fontName = self.titleLabel.font.fontName
            self.titleLabel.font = UIFont(name: fontName, size: newValue)
        }

        get {
            return self.titleLabel.font.pointSize
        }
    }

    @IBInspectable
    private var _subtitle: String? {
        get {
            return self.subtitleLabel.text
        }

        set(newValue) {
            self.subtitleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _subtitleColor: UIColor? {
        get {
            return self.subtitleLabel.textColor
        }

        set(newValue) {
            self.subtitleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _highlightedSubtitleColor: UIColor? {
        get {
            return self.subtitleLabel.highlightedTextColor
        }

        set(newValue) {
            self.subtitleLabel.highlightedTextColor = newValue
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                self.subtitleLabel.font = nil
                return
            }

            let pointSize = self.subtitleLabel.font.pointSize
            self.subtitleLabel.font = UIFont(name: fontName, size: pointSize)
        }

        get {
            return self.subtitleLabel.font.fontName
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        set(newValue) {
            let fontName = self.subtitleLabel.font.fontName
            self.subtitleLabel.font = UIFont(name: fontName, size: newValue)
        }

        get {
            return self.subtitleLabel.font.pointSize
        }
    }

    @IBInspectable
    private var _shadowColor: UIColor {
        get {
            return self.roundedBackgroundView!.shadowColor
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowColor = newValue
            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _shadowOffset: CGSize {
        get {
            return self.roundedBackgroundView!.shadowOffset
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOffset = newValue
        }
    }

    @IBInspectable
    private var _shadowRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.shadowRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowRadius = newValue
        }
    }

    @IBInspectable
    private var _shadowOpacity: Float {
        get {
            return self.roundedBackgroundView!.shadowOpacity
        }

        set(newValue) {
            self.roundedBackgroundView!.shadowOpacity = newValue
        }
    }

    @IBInspectable
    private var _cornerRadius: CGFloat {
        get {
            return self.roundedBackgroundView!.cornerRadius
        }

        set(newValue) {
            self.roundedBackgroundView!.cornerRadius = newValue
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
}
