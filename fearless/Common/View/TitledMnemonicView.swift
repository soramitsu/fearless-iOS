import UIKit

final class TitledMnemonicView: UIView {
    var iconView: UIImageView { lazyIconViewOrCreate() }
    var titleLabel: UILabel { lazyTitleLabelOrCreate() }
    private(set) var contentView: MnemonicDisplayView!

    private var lazyIconView: UIImageView?
    private var lazyTitleLabel: UILabel?

    private var calculatedTitleHeight: CGFloat = 0.0
    private var calculatedTitleWidth: CGFloat = 0.0
    private var calculatedContentHeight: CGFloat = 0.0

    func configureWrapping(locale: Locale, compatibleWith traits: UITraitCollection) {
        titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traits)
        contentView.adaptsToAvailableWidth = true
        contentView.indexFontInColumn = .fw(.monoS, locale: locale, compatibleWith: traits)
        contentView.wordFontInColumn = .fw(.phraseWord, locale: locale, compatibleWith: traits)
        contentView.verticalSpacingInColumn = 12
        calculatedTitleWidth = -1
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    var horizontalSpacing: CGFloat = 9 {
        didSet {
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 16 {
        didSet {
            setNeedsLayout()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    override var intrinsicContentSize: CGSize {
        let headerHeight = max(lazyTitleLabel?.intrinsicContentSize.height ?? 0.0, calculatedTitleHeight)

        var height = headerHeight

        if headerHeight > 0.0 {
            height += verticalSpacing
        }

        height += contentView.intrinsicContentSize.height

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        if let iconView = lazyIconView {
            let iconSize = iconView.intrinsicContentSize
            iconView.frame = CGRect(
                x: bounds.minX,
                y: bounds.minY,
                width: iconSize.width,
                height: iconSize.height
            )
        }

        if let titleLabel = lazyTitleLabel {
            let labelX: CGFloat

            if let iconView = lazyIconView {
                labelX = iconView.frame.maxX + horizontalSpacing
            } else {
                labelX = 0.0
            }

            let width = bounds.maxX - labelX

            if abs(calculatedTitleWidth - width) > CGFloat.leastNormalMagnitude {
                updateTitleSizeForWidth(width)
            }

            titleLabel.frame = CGRect(x: labelX, y: bounds.minY, width: width, height: calculatedTitleHeight)
        }

        let headerHeight = max(lazyIconView?.frame.maxY ?? 0.0, lazyTitleLabel?.frame.maxY ?? 0.0)
        let top = lazyIconView != nil || lazyTitleLabel != nil ? headerHeight + verticalSpacing : headerHeight

        contentView.frame = CGRect(
            x: bounds.minX,
            y: top,
            width: bounds.width,
            height: bounds.height - top
        )
        if contentView.adaptsToAvailableWidth {
            contentView.layoutIfNeeded()
            let height = contentView.intrinsicContentSize.height
            if calculatedContentHeight != height {
                calculatedContentHeight = height
                invalidateIntrinsicContentSize()
            }
        }
    }

    private func configure() {
        backgroundColor = .clear

        contentView = MnemonicDisplayView()
        contentView.backgroundColor = .clear
        addSubview(contentView)
    }

    private func lazyIconViewOrCreate() -> UIImageView {
        if let iconView = lazyIconView {
            return iconView
        }

        let iconView = UIImageView()
        addSubview(iconView)

        lazyIconView = iconView

        if superview != nil {
            setNeedsLayout()
        }

        return iconView
    }

    private func lazyTitleLabelOrCreate() -> UILabel {
        if let titleLabel = lazyTitleLabel {
            return titleLabel
        }

        let label = UILabel()
        label.backgroundColor = .clear
        label.numberOfLines = 0
        addSubview(label)

        lazyTitleLabel = label

        if superview != nil {
            setNeedsLayout()
        }

        return label
    }

    private func updateTitleSizeForWidth(_ width: CGFloat) {
        calculatedTitleWidth = width
        calculatedTitleHeight = titleLabel.sizeThatFits(CGSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )).height
        invalidateIntrinsicContentSize()
    }
}
