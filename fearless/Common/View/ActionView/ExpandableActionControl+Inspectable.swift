import UIKit

extension ExpandableActionControl {
    @IBInspectable
    private var _title: String? {
        get {
            titleLabel.text
        }

        set(newValue) {
            titleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            titleLabel.textColor
        }

        set(newValue) {
            titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _horizontalSpacing: CGFloat {
        get {
            horizontalSpacing
        }

        set(newValue) {
            horizontalSpacing = newValue
        }
    }

    @IBInspectable
    private var _verticalDisplacement: CGFloat {
        get {
            verticalDisplacement
        }

        set {
            verticalDisplacement = newValue
        }
    }

    @IBInspectable
    private var _strokeColor: UIColor {
        get {
            plusIndicator.strokeColor
        }

        set {
            plusIndicator.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _strokeWidth: CGFloat {
        get {
            plusIndicator.strokeWidth
        }

        set {
            plusIndicator.strokeWidth = newValue
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

            guard let pointSize = titleLabel.font?.pointSize else {
                titleLabel.font = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            titleLabel.font = UIFont(name: fontName, size: pointSize)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            if let pointSize = titleLabel.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }

        set(newValue) {
            guard let fontName = titleLabel.font?.fontName else {
                titleLabel.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            titleLabel.font = UIFont(name: fontName, size: newValue)

            invalidateLayout()
        }
    }

    @IBInspectable
    private var _minimumFontScale: CGFloat {
        get {
            titleLabel.minimumScaleFactor
        }

        set(newValue) {
            titleLabel.minimumScaleFactor = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _adjustsFontSizeToFitWidth: Bool {
        get {
            titleLabel.adjustsFontSizeToFitWidth
        }

        set(newValue) {
            titleLabel.adjustsFontSizeToFitWidth = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _layoutType: UInt {
        get {
            layoutType.rawValue
        }

        set(newValue) {
            guard let newType = LayoutType(rawValue: newValue) else {
                return
            }

            layoutType = newType
        }
    }
}
