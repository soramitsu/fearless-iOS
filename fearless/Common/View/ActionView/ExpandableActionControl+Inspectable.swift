import UIKit

extension ExpandableActionControl {
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
    private var _horizontalSpacing: CGFloat {
        get {
            return horizontalSpacing
        }

        set(newValue) {
            horizontalSpacing = newValue
        }
    }

    @IBInspectable
    private var _verticalDisplacement: CGFloat {
        get {
            return verticalDisplacement
        }

        set {
            verticalDisplacement = newValue
        }
    }

    @IBInspectable
    private var _strokeColor: UIColor {
        get {
            return plusIndicator.strokeColor
        }

        set {
            plusIndicator.strokeColor = newValue
        }
    }

    @IBInspectable
    private var _strokeWidth: CGFloat {
        get {
            return plusIndicator.strokeWidth
        }

        set {
            plusIndicator.strokeWidth = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        get {
            return self.titleLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                self.titleLabel.font = nil
                return
            }

            guard let pointSize = self.titleLabel.font?.pointSize else {
                self.titleLabel.font = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            self.titleLabel.font = UIFont(name: fontName, size: pointSize)

            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        get {
            if let pointSize = self.titleLabel.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }

        set(newValue) {
            guard let fontName = self.titleLabel.font?.fontName else {
                self.titleLabel.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            self.titleLabel.font = UIFont(name: fontName, size: newValue)

            self.invalidateLayout()
        }
    }

    @IBInspectable
    private var _minimumFontScale: CGFloat {
        get {
            return titleLabel.minimumScaleFactor
        }

        set(newValue) {
            titleLabel.minimumScaleFactor = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _adjustsFontSizeToFitWidth: Bool {
        get {
            return titleLabel.adjustsFontSizeToFitWidth
        }

        set(newValue) {
            titleLabel.adjustsFontSizeToFitWidth = newValue
            invalidateLayout()
        }
    }

    @IBInspectable
    private var _layoutType: UInt {
        get {
            return layoutType.rawValue
        }

        set(newValue) {
            guard let newType = LayoutType(rawValue: newValue) else {
                return
            }

            layoutType = newType
        }
    }

}
