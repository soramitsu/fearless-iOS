import Foundation
import SoraUI

class RewardSelectionView: BackgroundedContentControl {
    private(set) var titleLabel: UILabel!
    private(set) var incomeLabel: UILabel!
    private(set) var amountLabel: UILabel!
    private(set) var priceLabel: UILabel!
    private(set) var iconView: UIImageView!

    var triangularedBackgroundView: TriangularedView? {
        backgroundView as? TriangularedView
    }

    var horizontalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var verticalSpacing: CGFloat = 8.0 {
        didSet {
            setNeedsLayout()
        }
    }

    var selectionWidth: CGFloat = 48.0 {
        didSet {
            setNeedsLayout()
        }
    }

    override var isSelected: Bool {
        didSet {
            applySelectionState()
        }
    }

    override var intrinsicContentSize: CGSize {
        let topContentHeight = max(titleLabel.intrinsicContentSize.height, amountLabel.intrinsicContentSize.height)
        let bottomContentHeight = max(incomeLabel.intrinsicContentSize.height, priceLabel.intrinsicContentSize.height)

        let height = contentInsets.top + topContentHeight + verticalSpacing
            + bottomContentHeight + contentInsets.bottom

        return CGSize(width: UIView.noIntrinsicMetric, height: height)
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        configure()
    }

    override func prepareForInterfaceBuilder() {
        super.prepareForInterfaceBuilder()

        configure()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        contentView?.frame = bounds

        layoutMiddleContent()
        layoutTopContent()
        layoutBottomContent()
    }

    private func layoutMiddleContent() {
        iconView.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: selectionWidth,
            height: bounds.height
        )
    }

    private func layoutTopContent() {
        let availableWidth = bounds.width - selectionWidth - contentInsets.right

        let amountSize = amountLabel.intrinsicContentSize

        let amountClippedWidth = max(min(availableWidth, amountSize.width), 0.0)

        amountLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - amountClippedWidth,
            y: bounds.minY + contentInsets.top,
            width: amountClippedWidth,
            height: amountSize.height
        )

        let titleSize = titleLabel.intrinsicContentSize

        let titleClippedWidth = max(min(availableWidth - amountClippedWidth - horizontalSpacing, titleSize.width), 0)

        titleLabel.frame = CGRect(
            x: bounds.minX + selectionWidth,
            y: bounds.minY + contentInsets.top,
            width: titleClippedWidth,
            height: titleSize.height
        )
    }

    private func layoutBottomContent() {
        let availableWidth = bounds.width - selectionWidth - contentInsets.right

        let incomeSize = incomeLabel.intrinsicContentSize

        let incomeClippedWidth = max(min(availableWidth, incomeSize.width), 0.0)

        incomeLabel.frame = CGRect(
            x: bounds.minX + selectionWidth,
            y: bounds.maxY - contentInsets.bottom - incomeSize.height,
            width: incomeClippedWidth,
            height: incomeSize.height
        )

        let priceSize = priceLabel.intrinsicContentSize

        let priceClippedWidth = max(min(availableWidth - incomeClippedWidth - horizontalSpacing, priceSize.width), 0)

        priceLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - priceClippedWidth,
            y: bounds.maxY - contentInsets.bottom - priceSize.height,
            width: priceClippedWidth,
            height: priceSize.height
        )
    }

    // MARK: Configure

    private func configure() {
        backgroundColor = UIColor.clear

        configureBackgroundViewIfNeeded()
        configureContentViewIfNeeded()
        applyStyle()
    }

    private func configureBackgroundViewIfNeeded() {
        if backgroundView == nil {
            let triangularedView = TriangularedView()
            triangularedView.isUserInteractionEnabled = false
            triangularedView.shadowOpacity = 0.0

            backgroundView = triangularedView
        }
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

        if amountLabel == nil {
            amountLabel = UILabel()
            contentView?.addSubview(amountLabel)
        }

        if priceLabel == nil {
            priceLabel = UILabel()
            contentView?.addSubview(priceLabel)
        }

        if incomeLabel == nil {
            incomeLabel = UILabel()
            contentView?.addSubview(incomeLabel)
        }

        if iconView == nil {
            iconView = UIImageView()
            iconView.contentMode = .center
            contentView?.addSubview(iconView)
        }
    }

    private func applyStyle() {
        iconView.tintColor = triangularedBackgroundView?.highlightedStrokeColor
    }

    private func applySelectionState() {
        iconView.isHidden = !isSelected
    }
}
