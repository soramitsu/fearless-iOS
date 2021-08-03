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
            titleLabel.text
        }

        set {
            titleLabel.text = newValue
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
    var amountTitle: String? {
        get {
            amountLabel?.text
        }

        set {
            amountLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _amountFontName: String? {
        get {
            amountLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                amountLabel.font = nil
                return
            }

            let pointSize = amountLabel.font.pointSize

            amountLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _amountFontSize: CGFloat {
        get {
            amountLabel.font.pointSize
        }

        set(newValue) {
            let fontName = amountLabel.font.fontName

            amountLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var amountTitleColor: UIColor? {
        get {
            amountLabel.textColor
        }

        set {
            amountLabel.textColor = newValue
        }
    }

    @IBInspectable
    var priceTitle: String? {
        get {
            priceLabel.text
        }

        set {
            priceLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _priceFontName: String? {
        get {
            priceLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                priceLabel.font = nil
                return
            }

            let pointSize = priceLabel.font.pointSize

            priceLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _priceFontSize: CGFloat {
        get {
            priceLabel.font.pointSize
        }

        set(newValue) {
            let fontName = priceLabel.font.fontName

            priceLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var priceColor: UIColor? {
        get {
            priceLabel.textColor
        }

        set {
            priceLabel.textColor = newValue
        }
    }

    @IBInspectable
    var incomeTitle: String? {
        get {
            incomeLabel.text
        }

        set {
            incomeLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _incomeFontName: String? {
        get {
            incomeLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                incomeLabel.font = nil
                return
            }

            let pointSize = incomeLabel.font.pointSize

            incomeLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _incomeFontSize: CGFloat {
        get {
            incomeLabel.font.pointSize
        }

        set(newValue) {
            let fontName = incomeLabel.font.fontName

            incomeLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var incomeColor: UIColor? {
        get {
            incomeLabel.textColor
        }

        set {
            incomeLabel.textColor = newValue
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
