import UIKit
import Kingfisher
import simd
import SoraUI

final class ChainAccountBalanceTableCell: SwipableTableViewCell {
    enum LayoutConstants {
        static let cellHeight: CGFloat = 93
        static let assetImageTopOffset: CGFloat = 11
        static let stackViewVerticalOffset: CGFloat = 6
        static let iconSize: CGFloat = 48
        static let priceRowSize = CGSize(width: 50.0, height: 6.0)
        static let balanceRowSize = CGSize(width: 80.0, height: 12.0)
        static let balancePriceRowSize = CGSize(width: 56.0, height: 6.0)
    }

    private var backgroundTriangularedView: TriangularedView = {
        let containerView = TriangularedView()
        containerView.fillColor = R.color.colorWhite8()!
        containerView.highlightedFillColor = R.color.colorWhite8()!
        containerView.shadowOpacity = 0
        return containerView
    }()

    private var assetIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private var separatorView: UIView = {
        let view = UIView()
        view.backgroundColor = R.color.colorBlurSeparator()
        return view
    }()

    private var contentStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.spacing = 2
        stackView.axis = .vertical
        stackView.distribution = .fill
        stackView.alignment = .fill
        return stackView
    }()

    private var chainNameLabel: ShimmeredLabel = {
        let label = ShimmeredLabel()
        label.font = .capsTitle
        label.textColor = R.color.colorAlmostWhite()
        return label
    }()

    let chainInfoView = UIView()
    let chainOptionsView = UIFactory.default.createChainOptionsView()

    private var balanceView: HorizontalKeyValueView = {
        let view = HorizontalKeyValueView()
        let style = HorizontalKeyValueView.Style()
        view.apply(style: style)
        return view
    }()

    /// "Transferable X" under the total balance when they differ.
    private let transferableLabel: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorLightGray()
        label.textAlignment = .right
        label.adjustsFontForContentSizeCategory = true
        label.isHidden = true
        return label
    }()

    private var priceView: HorizontalKeyValueView = {
        let view = HorizontalKeyValueView()
        let style = HorizontalKeyValueView.Style(
            keyLabelFont: .p2Paragraph,
            valueLabelFont: .p2Paragraph,
            keyLabelTextColor: R.color.colorAlmostWhite(),
            valueLabelTextColor: R.color.colorAlmostWhite()
        )
        view.apply(style: style)
        return view
    }()

    private let chainInfoContainerView = UIStackView()
    private let metadataStackView = UIStackView()
    private var chainIconsView = ChainCollectionView()
    private var skeletonView: SkrullableView?
    private var isRestyledLoading = false
    private var loadingTargetFrames: [CGRect] = []

    private lazy var hideButton = SwipeCellButton.createHideButton(locale: locale)
    private lazy var showButton = SwipeCellButton.createShowButton(locale: locale)

    private var locale: Locale?
    private var showsNetwork = false
    private var isNestedToken = false

    override var cloudViewEdgeInsets: UIEdgeInsets {
        var insets = super.cloudViewEdgeInsets
        if isNestedToken {
            insets.left += FWAppearance.portfolioListRestyled && traitCollection.preferredContentSizeCategory
                .isAccessibilityCategory ? 12 : 16
        }
        return insets
    }

    // MARK: - Lifecycle

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
        updateTextLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        assetIconImageView.kf.cancelDownloadTask()

        chainOptionsView.arrangedSubviews.forEach { subview in
            chainOptionsView.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
    }

    // MARK: - Public methods

    func bind(to viewModel: ChainAccountBalanceCellViewModel, showsNetwork: Bool = false, indented: Bool = false) {
        if FWAppearance.portfolioListRestyled {
            locale = viewModel.locale
            hideButton = SwipeCellButton.createHideButton(locale: locale)
            showButton = SwipeCellButton.createShowButton(locale: locale)
        }
        self.showsNetwork = showsNetwork
        isNestedToken = indented
        cloudView.snp.updateConstraints { make in
            make.leading.equalToSuperview().offset(cloudViewEdgeInsets.left)
        }
        viewModel.imageViewModel?.cancel(on: assetIconImageView)

        balanceView.valueLabel.apply(state: viewModel.balanceString)
        transferableLabel.text = viewModel.transferableString
        transferableLabel.isHidden = viewModel.transferableString == nil
        priceView.valueLabel.apply(state: viewModel.totalAmountString)
        priceView.keyLabel.apply(state: viewModel.priceAttributedString)

        viewModel.imageViewModel?.loadBalanceListIcon(
            on: assetIconImageView,
            animated: false
        )

        chainOptionsView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if let options = viewModel.options {
            options.forEach { option in
                let view = ChainOptionsView()
                view.bind(to: option)

                chainOptionsView.addArrangedSubview(view)
            }
        }

        setDeactivated(!viewModel.chainAsset.chain.isSupported)
        controlSkeleton(for: viewModel)
        chainIconsView.bind(viewModel: viewModel.chainIconViewViewModel)
        chainOptionsView.isHidden = viewModel.options?.isEmpty != false
        chainIconsView.isHidden = viewModel.chainIconViewViewModel.chainImages.isEmpty
        metadataStackView.isHidden = chainOptionsView.isHidden && chainIconsView.isHidden
        leftMenuButtons = viewModel.swipeActionsEnabled ? createLeftButtons() : []
        if !viewModel.swipeActionsEnabled {
            rightMenuButtons = []
        } else if viewModel.metadataTrust.trust != .verified {
            rightMenuButtons = [hideButton, showButton]
        } else {
            rightMenuButtons = viewModel.hideButtonIsVisible ? [hideButton] : []
        }

        locale = viewModel.locale
        updateTextLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard FWAppearance.portfolioListRestyled, isRestyledLoading else { return }
        contentStackView.layoutIfNeeded()
        balanceView.layoutIfNeeded()
        priceView.layoutIfNeeded()
        let size = contentStackView.bounds.size
        let frames = [priceView.keyLabel, balanceView.valueLabel, priceView.valueLabel].map {
            $0.convert($0.bounds, to: contentStackView)
        }
        guard size.width > 0, size.height > 0,
              skeletonView?.bounds.size != size || frames != loadingTargetFrames else { return }
        loadingTargetFrames = frames
        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil
        setupLoadingSkeleton()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTextLayout()
    }

    // MARK: - Private methods

    private func configure() {
        leftMenuButtons = createLeftButtons()

        backgroundColor = .clear

        separatorInset = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        selectionStyle = .none
    }

    private func createLeftButtons() -> [SwipeButtonProtocol] {
        [
            SwipeCellButton.createSendButton(locale: locale),
            SwipeCellButton.createReceiveButton(locale: locale)
        ]
    }

    private func setupLayout() {
        cloudView.addSubview(backgroundTriangularedView)
        backgroundTriangularedView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.greaterThanOrEqualTo(LayoutConstants.cellHeight - cloudViewEdgeInsets.top)
        }

        backgroundTriangularedView.addSubview(assetIconImageView)

        assetIconImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(LayoutConstants.iconSize)
            make.centerY.equalToSuperview()
        }

        backgroundTriangularedView.addSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.width.equalTo(UIConstants.separatorHeight)
            make.leading.equalTo(assetIconImageView.snp.trailing).offset(UIConstants.defaultOffset)
        }

        backgroundTriangularedView.addSubview(contentStackView)

        contentStackView.snp.makeConstraints { make in
            make.leading.equalTo(separatorView.snp.trailing).offset(UIConstants.defaultOffset)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.top.equalTo(separatorView.snp.top)
            make.bottom.equalTo(separatorView.snp.bottom)
        }

        contentStackView.addArrangedSubview(chainInfoContainerView)
        chainInfoContainerView.snp.makeConstraints { make in
            make.width.equalToSuperview()
        }
        chainNameLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        contentStackView.addArrangedSubview(balanceView)
        balanceView.setContentHuggingPriority(.defaultHigh, for: .vertical)
        balanceView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }

        contentStackView.addArrangedSubview(transferableLabel)
        transferableLabel.setContentHuggingPriority(.defaultHigh, for: .vertical)

        contentStackView.addArrangedSubview(priceView)
        priceView.setContentHuggingPriority(.defaultLow, for: .vertical)
        priceView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }

        chainInfoContainerView.axis = .vertical
        chainInfoContainerView.spacing = 4
        chainInfoContainerView.addArrangedSubview(chainNameLabel)
        chainInfoContainerView.addArrangedSubview(metadataStackView)
        metadataStackView.spacing = UIConstants.defaultOffset
        metadataStackView.alignment = .center
        metadataStackView.addArrangedSubview(chainOptionsView)
        metadataStackView.addArrangedSubview(chainIconsView)
        chainIconsView.snp.makeConstraints { make in
            make.width.equalTo(90)
            make.height.equalTo(16)
        }
    }
}

extension ChainAccountBalanceTableCell: DeactivatableView {
    var deactivatableViews: [UIView] {
        [assetIconImageView, chainNameLabel, balanceView, transferableLabel, priceView]
    }
}

// MARK: - Skeleton

extension ChainAccountBalanceTableCell {
    private func controlSkeleton(for viewModel: ChainAccountBalanceCellViewModel) {
        let trustSuffix: String
        func trustText(_ key: String, fallback: String) -> String {
            FWAppearance.portfolioListRestyled
                ? PortfolioStrings.text(key, locale: viewModel.locale)
                : NSLocalizedString(key, value: fallback, comment: "")
        }
        switch viewModel.metadataTrust.trust {
        case .verified:
            trustSuffix = trustText("portfolio.asset.verified", fallback: "Verified")
        case .unverified:
            trustSuffix = trustText("portfolio.asset.detected", fallback: "Detected")
        case .missing:
            trustSuffix = trustText("portfolio.asset.metadata_missing", fallback: "Metadata missing")
        }
        let subtitle = showsNetwork ? viewModel.chainAsset.chain.name : viewModel.assetName?.uppercased()
        let chainName = [subtitle, trustSuffix.uppercased()]
            .compactMap { $0 }
            .joined(separator: " · ")
        let chainSymbol = viewModel.chainAsset.asset.symbolUppercased
        chainNameLabel.apply(state: .updating(chainName))
        balanceView.keyLabel.apply(state: .updating(chainSymbol))
        assetIconImageView.startShimmeringAnimation()
        if viewModel.isColdBoot {
            startLoading()
            return
        }

        stopLoadingIfNeeded()
        assetIconImageView.stopShimmeringAnimation()
        chainNameLabel.apply(state: .normal(chainName))
        balanceView.keyLabel.apply(state: .normal(chainSymbol))
    }

    private func startLoading() {
        if FWAppearance.portfolioListRestyled {
            isRestyledLoading = true
            priceView.keyLabel.alpha = 0
            priceView.valueLabel.alpha = 0
            balanceView.valueLabel.alpha = 0
            transferableLabel.alpha = 0
            setNeedsLayout()
            return
        }
        layoutIfNeeded()
        guard skeletonView == nil, backgroundTriangularedView.frame.size != .zero else {
            return
        }

        priceView.keyLabel.alpha = 0
        priceView.valueLabel.alpha = 0
        balanceView.valueLabel.alpha = 0
        transferableLabel.alpha = 0

        setupLoadingSkeleton()
    }

    private func stopLoadingIfNeeded() {
        if FWAppearance.portfolioListRestyled {
            isRestyledLoading = false
            priceView.keyLabel.alpha = 1
            priceView.valueLabel.alpha = 1
            balanceView.valueLabel.alpha = 1
            transferableLabel.alpha = 1
        }
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        priceView.keyLabel.alpha = 1
        priceView.valueLabel.alpha = 1
        balanceView.valueLabel.alpha = 1
        transferableLabel.alpha = 1
    }

    private func setupLoadingSkeleton() {
        let spaceSize = contentStackView.frame.size
        guard spaceSize.width > 0, spaceSize.height > 0 else {
            return
        }

        let skeletonView = Skrull(
            size: spaceSize,
            decorations: [],
            skeletons: createLoadingSkeletons(for: spaceSize)
        )
        .fillSkeletonStart(R.color.colorSkeletonStart()!)
        .fillSkeletonEnd(color: R.color.colorSkeletonEnd()!)
        .build()

        skeletonView.frame = CGRect(origin: .zero, size: spaceSize)
        skeletonView.autoresizingMask = []
        contentStackView.addSubview(skeletonView)

        self.skeletonView = skeletonView

        skeletonView.startSkrulling()
    }

    private func createRestyledLoadingSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        let placements: [(UIView, CGSize)] = [
            (priceView.keyLabel, LayoutConstants.priceRowSize),
            (balanceView.valueLabel, LayoutConstants.balanceRowSize),
            (priceView.valueLabel, LayoutConstants.balancePriceRowSize)
        ]
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        return placements.map { label, preferredSize in
            let frame = label.convert(label.bounds, to: contentStackView)
            let size = CGSize(
                width: min(preferredSize.width, spaceSize.width),
                height: min(preferredSize.height, spaceSize.height)
            )
            let positionX = label !== priceView.keyLabel && !stacked ? frame.maxX - size.width : frame.minX
            let position = CGPoint(
                x: max(0, min(positionX, spaceSize.width - size.width)),
                y: max(size.height / 2, min(frame.midY, spaceSize.height - size.height / 2))
            )
            return SingleSkeleton.createRow(spaceSize: spaceSize, position: position, size: size)
        }
    }

    private func createLoadingSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        if FWAppearance.portfolioListRestyled {
            return createRestyledLoadingSkeletons(for: spaceSize)
        }
        return [
            SingleSkeleton.createRow(
                under: priceView.keyLabel,
                containerView: contentStackView,
                spaceSize: spaceSize,
                offset: CGPoint(
                    x: 0,
                    y: -(LayoutConstants.priceRowSize.height + priceView.keyLabel.frame.height) / 2
                ),
                size: LayoutConstants.priceRowSize
            ),

            SingleSkeleton.createRow(
                under: balanceView.valueLabel,
                containerView: contentStackView,
                spaceSize: spaceSize,
                offset: CGPoint(
                    x: -LayoutConstants.balanceRowSize.width + balanceView.valueLabel.frame.width,
                    y: -(LayoutConstants.balanceRowSize.height + balanceView.valueLabel.frame.height) / 2
                ),
                size: LayoutConstants.balanceRowSize
            ),

            SingleSkeleton.createRow(
                under: priceView.valueLabel,
                containerView: contentStackView,
                spaceSize: spaceSize,
                offset: CGPoint(
                    x: -LayoutConstants.balancePriceRowSize.width + priceView.valueLabel.frame.width,
                    y: -(LayoutConstants.balancePriceRowSize.height + priceView.valueLabel.frame.height) / 2
                ),
                size: LayoutConstants.balancePriceRowSize
            )
        ]
    }
}

private extension ChainAccountBalanceTableCell {
    func updateTextLayout() {
        if FWAppearance.portfolioListRestyled {
            chainNameLabel.font = .fw(.labelM, compatibleWith: traitCollection)
            balanceView.keyLabel.font = .fw(.titleS, compatibleWith: traitCollection)
            balanceView.valueLabel.font = .fw(.numberL, compatibleWith: traitCollection)
            transferableLabel.font = .fw(.bodyS, compatibleWith: traitCollection)
            priceView.keyLabel.font = .fw(.numberS, compatibleWith: traitCollection)
            priceView.valueLabel.font = .fw(.numberM, compatibleWith: traitCollection)
            updateAccessibleColumns()
        }
        let axis: NSLayoutConstraint.Axis = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? .vertical : .horizontal
        balanceView.axis = axis
        priceView.axis = axis
        [
            chainNameLabel,
            balanceView.keyLabel,
            balanceView.valueLabel,
            transferableLabel,
            priceView.keyLabel,
            priceView.valueLabel
        ].forEach {
            $0.numberOfLines = 0
            $0.lineBreakMode = FWAppearance.portfolioListRestyled ? .byWordWrapping : .byCharWrapping
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
    }

    func updateAccessibleColumns() {
        let stacked = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        cloudView.snp.updateConstraints { $0.leading.equalToSuperview().offset(cloudViewEdgeInsets.left) }
        assetIconImageView.snp.remakeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.size.equalTo(stacked ? 28 : LayoutConstants.iconSize)
            if stacked {
                make.top.equalToSuperview().inset(UIConstants.defaultOffset)
            } else {
                make.centerY.equalToSuperview()
            }
        }
        separatorView.isHidden = stacked
        contentStackView.snp.remakeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            if stacked {
                make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
                make.top.equalTo(assetIconImageView.snp.bottom).offset(UIConstants.defaultOffset)
            } else {
                make.leading.equalTo(separatorView.snp.trailing).offset(UIConstants.defaultOffset)
                make.top.equalToSuperview().inset(UIConstants.defaultOffset)
            }
        }
        balanceView.valueLabel.textAlignment = stacked ? .left : .right
        priceView.valueLabel.textAlignment = stacked ? .left : .right
        transferableLabel.textAlignment = stacked ? .left : .right
    }
}
