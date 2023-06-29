import Foundation
import SoraUI

class RewardSelectionView: BackgroundedContentControl {
    private(set) var titleLabel: UILabel!
    private(set) var incomeLabel: UILabel!
    private(set) var amountLabel: UILabel!
    private(set) var priceLabel: UILabel!
    private(set) var iconView: UIImageView!
    private var skeletonView: SkrullableView?

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

extension RewardSelectionView: SkeletonLoadable {
    func didDisappearSkeleton() {
        skeletonView?.stopSkrulling()
    }

    func didAppearSkeleton() {
        skeletonView?.stopSkrulling()
        skeletonView?.startSkrulling()
    }

    func didUpdateSkeletonLayout() {
        guard let skeletonView = skeletonView else {
            return
        }

        if skeletonView.frame.size != frame.size {
            skeletonView.removeFromSuperview()
            self.skeletonView = nil
            setupSkeleton()
        }
    }

    func startLoadingIfNeeded() {
        guard skeletonView == nil else {
            return
        }

        titleLabel.alpha = 0.0
        incomeLabel.alpha = 0.0
        priceLabel.alpha = 0.0
        amountLabel.alpha = 0.0

        setupSkeleton()
    }

    func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        titleLabel.alpha = 1.0
        incomeLabel.alpha = 1.0
        priceLabel.alpha = 1.0
        amountLabel.alpha = 1.0
    }

    private func setupSkeleton() {
        guard let contentView = contentView else {
            return
        }

        let spaceSize = frame.size

        guard spaceSize != .zero else {
            self.skeletonView = Skrull(size: .zero, decorations: [], skeletons: []).build()
            return
        }

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        self.skeletonView = skeletonView

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        insertSubview(skeletonView, aboveSubview: contentView)

        skeletonView.startSkrulling()
    }

    private func createSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let defaultBigWidth = 72.0
        let defaultSmallWidth = 20.0
        let defaultHeight = 10.0

        let titleWidth = titleLabel.text?.widthOfString(usingFont: titleLabel.font)
        let incomeWidth = incomeLabel.text?.widthOfString(usingFont: incomeLabel.font)
        let priceWidth = priceLabel.text?.widthOfString(usingFont: priceLabel.font)
        let amountWidth = amountLabel.text?.widthOfString(usingFont: amountLabel.font)

        let titleSize = CGSize(width: titleWidth ?? defaultBigWidth, height: defaultHeight)
        let incomeSize = CGSize(width: incomeWidth ?? defaultBigWidth, height: defaultHeight)
        let priceSize = CGSize(width: priceWidth ?? defaultSmallWidth, height: defaultHeight)
        let amountSize = CGSize(width: amountWidth ?? defaultSmallWidth, height: defaultHeight)

        return [
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: selectionWidth + UIConstants.defaultOffset, y: spaceSize.height / 2 - titleSize.height / 2 - UIConstants.defaultOffset / 2),
                size: titleSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: selectionWidth + UIConstants.defaultOffset, y: spaceSize.height / 2 + incomeSize.height / 2 + UIConstants.defaultOffset / 2),
                size: incomeSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: spaceSize.width - UIConstants.defaultOffset - amountSize.width, y: spaceSize.height / 2 - amountSize.height),
                size: amountSize
            ),
            SingleSkeleton.createRow(
                spaceSize: spaceSize,
                position: CGPoint(x: spaceSize.width - UIConstants.defaultOffset - priceSize.width, y: spaceSize.height / 2 + priceSize.height),
                size: priceSize
            )
        ]
    }
}
