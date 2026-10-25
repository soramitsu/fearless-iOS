import UIKit

@IBDesignable
final class BorderedSubtitleActionView: TriangularedView {
    let actionControl = SubtitleActionControl()
    var wrapsContent = false

    func configureWrapping(locale: Locale, compatibleWith traits: UITraitCollection) {
        wrapsContent = true
        // A fixed-size icon must not constrain the multiline subtitle's height.
        actionControl.contentView.subtitleStackView.alignment = .center
        actionControl.contentView.titleLabel.numberOfLines = 0
        actionControl.contentView.subtitleLabelView.numberOfLines = 0
        actionControl.contentView.titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        actionControl.contentView.subtitleLabelView.font = .fw(.bodyL, locale: locale, compatibleWith: traits)
        invalidateLayout()
    }

    private func updateWrappingWidth() {
        guard wrapsContent, bounds.width > 0 else { return }
        let width = max(
            1,
            bounds.width - contentInsets.left - contentInsets.right
                - actionControl.contentInsets.left - actionControl.contentInsets.right
                - actionControl.horizontalSpacing - actionControl.imageIndicator.intrinsicContentSize.width
        )
        let content = actionControl.contentView!
        let subtitleWidth = max(1, width - (content.subtitleImageView.isHidden ? 0 : 19))
        if content.titleLabel.preferredMaxLayoutWidth != width ||
            content.subtitleLabelView.preferredMaxLayoutWidth != subtitleWidth {
            content.titleLabel.preferredMaxLayoutWidth = width
            content.subtitleLabelView.preferredMaxLayoutWidth = subtitleWidth
            content.invalidateLayout()
            actionControl.invalidateLayout()
            invalidateIntrinsicContentSize()
        }
    }

    var contentInsets = UIEdgeInsets(top: 8.0, left: 16, bottom: 8.0, right: 16) {
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
        updateWrappingWidth()
        let contentSize = actionControl.intrinsicContentSize

        return CGSize(
            width: contentSize.width + contentInsets.left + contentInsets.right,
            height: max(wrapsContent ? 60 : 0, contentSize.height + contentInsets.top + contentInsets.bottom)
        )
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateWrappingWidth()

        actionControl.frame = CGRect(
            x: contentInsets.left,
            y: contentInsets.top,
            width: bounds.size.width - contentInsets.left - contentInsets.right,
            height: bounds.size.height - contentInsets.top - contentInsets.bottom
        )
    }
}

extension BorderedSubtitleActionView {
    func disable() {
        super.applyDisabledStyle()
        actionControl.isUserInteractionEnabled = false
        actionControl.imageIndicator.isHidden = true
    }

    func enable() {
        super.applyEnabledStyle()
        actionControl.isUserInteractionEnabled = true
        actionControl.imageIndicator.isHidden = false
    }
}
