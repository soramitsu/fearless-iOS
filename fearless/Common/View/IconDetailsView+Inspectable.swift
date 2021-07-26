import UIKit

extension IconDetailsView {
    @IBInspectable
    var details: String? {
        get {
            detailsLabel.text
        }

        set {
            detailsLabel.text = newValue
            setNeedsLayout()
        }
    }

    @IBInspectable
    var detailsColor: UIColor? {
        get {
            detailsLabel.textColor
        }

        set {
            detailsLabel.textColor = newValue
        }
    }

    @IBInspectable
    private var _detailsFontName: String? {
        get {
            detailsLabel.font.fontName
        }

        set(newValue) {
            guard let fontName = newValue else {
                detailsLabel.font = nil
                return
            }

            let pointSize = detailsLabel.font.pointSize

            detailsLabel.font = UIFont(name: fontName, size: pointSize)

            setNeedsLayout()
        }
    }

    @IBInspectable
    private var _detailsFontSize: CGFloat {
        get {
            detailsLabel.font.pointSize
        }

        set(newValue) {
            detailsLabel.font = UIFont(name: detailsLabel.font.fontName, size: newValue)

            setNeedsLayout()
        }
    }

    @IBInspectable
    var icon: UIImage? {
        get {
            imageView.image
        }

        set {
            imageView.image = newValue
            setNeedsLayout()
        }
    }
}
