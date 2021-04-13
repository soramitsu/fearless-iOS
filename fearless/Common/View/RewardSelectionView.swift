import Foundation
import SoraUI

class RewardSelectionView: BackgroundedContentControl {
    private(set) var titleLabel: UILabel!
    private(set) var subtitleLabel: UILabel!
    private(set) var earningsTitleLabel: UILabel!
    private(set) var earningsSubtitleLabel: UILabel!
    private(set) var iconView: UIButton!

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
        let topContentHeight = max(
            titleLabel.intrinsicContentSize.height,
            earningsTitleLabel.intrinsicContentSize.height
        )
        let bottomContentHeight = max(
            subtitleLabel.intrinsicContentSize.height,
            earningsSubtitleLabel.intrinsicContentSize.height
        )

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

        iconView.frame = CGRect(
            x: bounds.minX,
            y: bounds.minY,
            width: selectionWidth,
            height: bounds.height
        )

        layoutTopContent()
        layoutBottomContent()
    }

    private func layoutTopContent() {
        let availableWidth = bounds.width - selectionWidth - contentInsets.right
        let titleSize = titleLabel.intrinsicContentSize
        let earningsSize = earningsTitleLabel.intrinsicContentSize

        let centerY = bounds.minY + contentInsets.top + max(titleSize.height, earningsSize.height) / 2.0

        titleLabel.frame = CGRect(
            x: bounds.minX + selectionWidth,
            y: centerY - titleSize.height / 2.0,
            width: min(availableWidth, titleSize.width),
            height: titleSize.height
        )

        let estimatedEarningsWidth = bounds.maxX - contentInsets.right
            - titleLabel.frame.maxX - horizontalSpacing
        let earningsWidth = max(min(estimatedEarningsWidth, earningsSize.width), 0.0)

        earningsTitleLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - earningsWidth,
            y: centerY - earningsSize.height / 2.0,
            width: earningsWidth,
            height: earningsSize.height
        )
    }

    private func layoutBottomContent() {
        let availableWidth = bounds.width - selectionWidth - contentInsets.right
        let subtitleSize = subtitleLabel.intrinsicContentSize
        let earningsSize = earningsSubtitleLabel.intrinsicContentSize

        let centerY = bounds.maxY - contentInsets.bottom -
            max(subtitleSize.height, earningsSize.height) / 2.0

        subtitleLabel.frame = CGRect(
            x: bounds.minX + selectionWidth,
            y: centerY - subtitleSize.height / 2.0,
            width: min(availableWidth, subtitleSize.width),
            height: subtitleSize.height
        )

        let estimatedEarningsWidth = bounds.maxX - contentInsets.right
            - subtitleLabel.frame.maxX - horizontalSpacing
        let earningsWidth = max(min(estimatedEarningsWidth, earningsSize.width), 0.0)

        earningsSubtitleLabel.frame = CGRect(
            x: bounds.maxX - contentInsets.right - earningsWidth,
            y: centerY - earningsSize.height / 2.0,
            width: earningsWidth,
            height: earningsSize.height
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

        if earningsTitleLabel == nil {
            earningsTitleLabel = UILabel()
            contentView?.addSubview(earningsTitleLabel)
        }

        if subtitleLabel == nil {
            subtitleLabel = UILabel()
            contentView?.addSubview(subtitleLabel)
        }

        if earningsSubtitleLabel == nil {
            earningsSubtitleLabel = UILabel()
            contentView?.addSubview(earningsSubtitleLabel)
        }

        if iconView == nil {
            iconView = UIButton()
            iconView.contentMode = .center
            contentView?.addSubview(iconView)
        }
    }

    private func applyStyle() {
        iconView.tintColor = triangularedBackgroundView?.highlightedStrokeColor
    }

    private func applySelectionState() {
        iconView.isSelected = isSelected
    }
}
