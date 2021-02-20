import UIKit

@IBDesignable
extension AmountInputView {
    @IBInspectable
    var fillColor: UIColor {
        get {
            triangularedBackgroundView!.fillColor
        }

        set {
            triangularedBackgroundView!.fillColor = newValue
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
            triangularedBackgroundView!.highlightedStrokeColor = newValue
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
    var priceText: String? {
        get {
            return priceLabel?.text
        }

        set {
            priceLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _priceFontName: String? {
        get {
            return priceLabel.font.fontName
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
            return priceLabel.textColor
        }

        set {
            priceLabel.textColor = newValue
        }
    }

    @IBInspectable
    var balanceText: String? {
        get {
            return balanceLabel?.text
        }

        set {
            balanceLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _balanceFontName: String? {
        get {
            return balanceLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                balanceLabel.font = nil
                return
            }

            let pointSize = balanceLabel.font.pointSize

            balanceLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _balanceFontSize: CGFloat {
        get {
            balanceLabel.font.pointSize
        }

        set(newValue) {
            let fontName = balanceLabel.font.fontName

            balanceLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var balanceColor: UIColor? {
        get {
            return balanceLabel.textColor
        }

        set {
            balanceLabel.textColor = newValue
        }
    }

    @IBInspectable
    var symbol: String? {
        get {
            return symbolLabel?.text
        }

        set {
            symbolLabel?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _symbolFontName: String? {
        get {
            return symbolLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                symbolLabel.font = nil
                return
            }

            let pointSize = symbolLabel.font.pointSize

            symbolLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _symbolFontSize: CGFloat {
        get {
            symbolLabel.font.pointSize
        }

        set(newValue) {
            let fontName = symbolLabel.font.fontName

            symbolLabel.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var symbolColor: UIColor? {
        get {
            return symbolLabel.textColor
        }

        set {
            symbolLabel.textColor = newValue
        }
    }

    @IBInspectable
    var fieldText: String? {
        get {
            return textField?.text
        }

        set {
            textField?.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _filedFontName: String? {
        get {
            return textField.font?.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                textField.font = nil
                return
            }

            let pointSize = textField.font?.pointSize ?? UIFont.labelFontSize

            textField.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _fieldFontSize: CGFloat {
        get {
            textField.font?.pointSize ?? 0.0
        }

        set(newValue) {
            let fontName = textField.font?.fontName ??
                UIFont.systemFont(ofSize: UIFont.labelFontSize).fontName

            textField.font = UIFont(name: fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var fieldColor: UIColor? {
        get {
            return textField.textColor
        }

        set {
            textField.textColor = newValue
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
    private var _verticalSpacing: CGFloat {
        get {
            verticalSpacing
        }

        set {
            verticalSpacing = newValue
        }
    }

    @IBInspectable
    private var _top: CGFloat {
        get {
            return self.contentInsets.top
        }

        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: newValue,
                                              left: insets.left,
                                              bottom: insets.bottom,
                                              right: insets.right)
        }
    }

    @IBInspectable
    private var _left: CGFloat {
        get {
            return self.contentInsets.top
        }

        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: newValue,
                                              bottom: insets.bottom,
                                              right: insets.right)
        }
    }

    @IBInspectable
    private var _bottom: CGFloat {
        get {
            return self.contentInsets.top
        }

        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: insets.left,
                                              bottom: newValue,
                                              right: insets.right)
        }
    }

    @IBInspectable
    private var _right: CGFloat {
        get {
            return self.contentInsets.top
        }

        set(newValue) {
            let insets = self.contentInsets
            self.contentInsets = UIEdgeInsets(top: insets.top,
                                              left: insets.left,
                                              bottom: insets.bottom,
                                              right: newValue)
        }
    }

    @IBInspectable
    private var _inputIndicatorColor: UIColor {
        get {
            return textField.tintColor
        }

        set {
            textField.tintColor = newValue
        }
    }
}
