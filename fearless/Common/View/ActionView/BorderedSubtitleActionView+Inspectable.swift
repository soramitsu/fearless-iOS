import UIKit
import SoraUI

extension BorderedSubtitleActionView {
    @IBInspectable
    private var _title: String? {
        get {
            return actionControl.contentView.titleLabel.text
        }

        set {
            actionControl.contentView.titleLabel.text = newValue
        }
    }

    @IBInspectable
    private var _titleColor: UIColor? {
        get {
            return actionControl.contentView.titleLabel.textColor
        }

        set {
            actionControl.contentView.titleLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _titleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                actionControl.contentView.titleLabel.font = nil
                return
            }

            guard let pointSize = actionControl.contentView.titleLabel.font?.pointSize else {
                actionControl.contentView.titleLabel.font = UIFont(name: fontName, size: UIFont.buttonFontSize)
                return
            }

            actionControl.contentView.titleLabel.font = UIFont(name: fontName, size: pointSize)

            self.invalidateLayout()
        }

        get {
            return actionControl.contentView.titleLabel.font.fontName
        }
    }

    @IBInspectable
    private var _titleFontSize: CGFloat {
        set(newValue) {
            guard let fontName = actionControl.contentView.titleLabel.font?.fontName else {
                actionControl.contentView.titleLabel.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            actionControl.contentView.titleLabel.font = UIFont(name: fontName, size: newValue)

            self.invalidateLayout()
        }

        get {
            if let pointSize = actionControl.contentView.titleLabel.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _subtitle: String? {
        get {
            return actionControl.contentView.subtitleLabelView.text
        }

        set {
            actionControl.contentView.subtitleLabelView.text = newValue
        }
    }

    @IBInspectable
    private var _subtitleColor: UIColor? {
        get {
            return actionControl.contentView.subtitleLabelView.textColor
        }

        set {
            actionControl.contentView.subtitleLabelView.textColor = newValue
        }
    }

    @IBInspectable
    private var _subtitleFontName: String? {
        set(newValue) {
            guard let fontName = newValue else {
                actionControl.contentView.subtitleLabelView.font = nil
                return
            }

            guard let pointSize = actionControl.contentView.subtitleLabelView.font?.pointSize else {
                actionControl.contentView.subtitleLabelView.font = UIFont(name: fontName,
                                                                          size: UIFont.buttonFontSize)
                return
            }

            actionControl.contentView.subtitleLabelView.font = UIFont(name: fontName, size: pointSize)

            self.invalidateLayout()
        }

        get {
            return actionControl.contentView.subtitleLabelView.font?.fontName
        }
    }

    @IBInspectable
    private var _subtitleFontSize: CGFloat {
        set(newValue) {
            guard let fontName = actionControl.contentView.subtitleLabelView.font?.fontName else {
                actionControl.contentView.subtitleLabelView.font = UIFont.systemFont(ofSize: newValue)
                return
            }

            actionControl.contentView.subtitleLabelView.font = UIFont(name: fontName, size: newValue)

            self.invalidateLayout()
        }

        get {
            if let pointSize = actionControl.contentView.subtitleLabelView.font?.pointSize {
                return pointSize
            } else {
                return 0.0
            }
        }
    }

    @IBInspectable
    private var _subtitleIcon: UIImage? {
        get {
            return actionControl.contentView.subtitleImageView.image
        }

        set {
            actionControl.contentView.subtitleImageView.image = newValue
        }
    }

    @IBInspectable
    private var _indicatorIcon: UIImage? {
        get {
            return actionControl.imageIndicator.image
        }

        set {
            actionControl.imageIndicator.image = newValue
        }
    }

    @IBInspectable
    private var _layoutType: UInt {
        set(newValue) {
            guard let newType = BaseActionControl.LayoutType(rawValue: newValue) else {
                return
            }

            actionControl.layoutType = newType
        }

        get {
            return actionControl.layoutType.rawValue
        }
    }

}
