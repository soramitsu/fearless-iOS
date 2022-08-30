import SoraUI
import UIKit

final class InputTriangularedView: BackgroundedContentControl {
    var triangularedBackgroundView: TriangularedView? {
        backgroundView as? TriangularedView
    }

    private(set) var titleLabel: UILabel!
    private(set) var textField: UITextField!

    var iconView: UIImageView { lazyIconViewOrCreateIfNeeded() }
    var actionView: UIImageView { lazyActionViewOrCreateIfNeeded() }

    private var lazyIconView: UIImageView?
    private var lazyActionView: UIImageView?

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var iconRadius: CGFloat = 16.0 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        if let actionView = lazyActionView {
            actionView.frame = CGRect(
                x: bounds.maxX - bounds.height,
                y: bounds.minY,
                width: bounds.height,
                height: bounds.height
            )
        }

        let titleHeight = titleLabel.intrinsicContentSize.height

        let iconOffset = lazyIconView != nil ? 2.0 * iconRadius + horizontalSpacing : 0.0
        let labelX = bounds.minX + contentInsets.left + iconOffset

        let trailing = lazyActionView?.frame.minX ?? bounds.maxX - contentInsets.right
        titleLabel.frame = CGRect(
            x: labelX,
            y: bounds.minY + contentInsets.top,
            width: trailing - labelX,
            height: titleHeight
        )

        let textFieldHeight = textField.intrinsicContentSize.height
        textField.frame = CGRect(
            x: labelX,
            y: bounds.maxY - contentInsets.bottom - textFieldHeight,
            width: trailing - labelX,
            height: textFieldHeight
        )

        if let iconView = lazyIconView {
            iconView.frame = CGRect(
                x: bounds.minX + contentInsets.left,
                y: bounds.midY - iconRadius,
                width: 2.0 * iconRadius,
                height: 2.0 * iconRadius
            )
        }
    }

    private func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let triangularedView = TriangularedView()
            triangularedView.isUserInteractionEnabled = false
            triangularedView.shadowOpacity = 0.0

            backgroundView = triangularedView
        }
    }

    private func lazyActionViewOrCreateIfNeeded() -> UIImageView {
        if let actionButton = lazyActionView {
            return actionButton
        }

        let imageView = UIImageView()
        imageView.contentMode = .center
        contentView?.addSubview(imageView)

        lazyActionView = imageView

        if superview != nil {
            setNeedsLayout()
        }

        return imageView
    }

    private func lazyIconViewOrCreateIfNeeded() -> UIImageView {
        if let iconView = lazyIconView {
            return iconView
        }

        let imageView = UIImageView()
        contentView?.addSubview(imageView)

        lazyIconView = imageView

        if superview != nil {
            setNeedsLayout()
        }

        return imageView
    }

    private func configureContentViewIfNeeded() {
        if contentView == nil {
            let contentView = UIView()
            contentView.backgroundColor = .clear
            contentView.isUserInteractionEnabled = false
            self.contentView = contentView
        }

        if titleLabel == nil {
            titleLabel = UILabel()
            contentView?.addSubview(titleLabel)
        }

        if textField == nil {
            textField = UITextField()
            contentView?.addSubview(titleLabel)
        }
    }
}
