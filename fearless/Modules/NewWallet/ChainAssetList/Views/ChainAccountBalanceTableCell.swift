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
        stackView.spacing = 0
        stackView.axis = .vertical
        stackView.distribution = .fillEqually
        stackView.alignment = .leading
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

    private var chainInfoContainerView = UIView()
    private var chainIconsView = ChainCollectionView()
    private var skeletonView: SkrullableView?

    private lazy var hideButton = SwipeCellButton.createHideButton(locale: locale)
    private lazy var showButton = SwipeCellButton.createShowButton(locale: locale)

    private var locale: Locale?

    // MARK: - Lifecycle

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        configure()
        setupLayout()
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

    func bind(to viewModel: ChainAccountBalanceCellViewModel) {
        viewModel.imageViewModel?.cancel(on: assetIconImageView)

        balanceView.valueLabel.apply(state: viewModel.balanceString)
        priceView.valueLabel.apply(state: viewModel.totalAmountString)
        priceView.keyLabel.apply(state: viewModel.priceAttributedString)

        viewModel.imageViewModel?.loadBalanceListIcon(
            on: assetIconImageView,
            animated: false
        )

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
        rightMenuButtons = viewModel.hideButtonIsVisible ? [hideButton] : []

        locale = viewModel.locale
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

        contentStackView.addArrangedSubview(priceView)
        priceView.setContentHuggingPriority(.defaultLow, for: .vertical)
        priceView.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
        }

        chainInfoContainerView.addSubview(chainNameLabel)
        chainNameLabel.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
        }
        chainInfoContainerView.addSubview(chainOptionsView)
        chainOptionsView.snp.makeConstraints { make in
            make.leading.equalTo(chainNameLabel.snp.trailing).offset(UIConstants.bigOffset)
            make.top.bottom.equalToSuperview()
        }
        chainInfoContainerView.addSubview(chainIconsView)
        chainIconsView.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(chainOptionsView.snp.trailing).offset(UIConstants.bigOffset)
            make.top.bottom.trailing.equalToSuperview()
            make.width.equalTo(90).priority(.low)
        }
    }
}

extension ChainAccountBalanceTableCell: DeactivatableView {
    var deactivatableViews: [UIView] {
        [assetIconImageView, chainNameLabel, balanceView, priceView]
    }
}

// MARK: - Skeleton

extension ChainAccountBalanceTableCell {
    private func controlSkeleton(for viewModel: ChainAccountBalanceCellViewModel) {
        let chainName = viewModel.assetName?.uppercased()
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
        layoutIfNeeded()
        guard skeletonView == nil, backgroundTriangularedView.frame.size != .zero else {
            return
        }

        priceView.keyLabel.alpha = 0
        priceView.valueLabel.alpha = 0
        balanceView.valueLabel.alpha = 0

        setupLoadingSkeleton()
    }

    private func stopLoadingIfNeeded() {
        guard skeletonView != nil else {
            return
        }

        skeletonView?.stopSkrulling()
        skeletonView?.removeFromSuperview()
        skeletonView = nil

        priceView.keyLabel.alpha = 1
        priceView.valueLabel.alpha = 1
        balanceView.valueLabel.alpha = 1
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

    private func createLoadingSkeletons(for spaceSize: CGSize) -> [Skeletonable] {
        [
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
