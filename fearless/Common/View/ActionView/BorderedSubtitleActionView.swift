import UIKit

@IBDesignable
final class BorderedSubtitleActionView: TriangularedView {
    let actionControl: SubtitleActionControl = SubtitleActionControl()

    var contentInsets: UIEdgeInsets = UIEdgeInsets(top: 8.0, left: 16, bottom: 8.0, right: 16) {
        didSet {
            invalidateLayout()
        }
    }

    override func configure() {
        super.configure()

        if actionControl.superview == nil {
            addSubview(actionControl)
        }
    }

    func invalidateLayout() {
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    override var intrinsicContentSize: CGSize {
        let contentSize = actionControl.intrinsicContentSize

        return CGSize(width: contentSize.width + contentInsets.left + contentInsets.right,
                      height: contentSize.height + contentInsets.top + contentInsets.bottom)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        actionControl.frame = CGRect(x: contentInsets.left,
                                     y: contentInsets.top,
                                     width: bounds.size.width - contentInsets.left - contentInsets.right,
                                     height: bounds.size.height - contentInsets.top - contentInsets.bottom)
    }
}
