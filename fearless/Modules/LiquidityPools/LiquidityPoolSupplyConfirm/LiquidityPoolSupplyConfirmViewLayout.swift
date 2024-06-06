import UIKit

final class LiquidityPoolSupplyConfirmViewLayout: UIView {
    private enum Constants {
        static let navigationBarHeight: CGFloat = 56.0
        static let backButtonSize = CGSize(width: 32, height: 32)
    }

    let navigationViewContainer = UIView()

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(
            top: 24.0,
            left: 0.0,
            bottom: UIConstants.actionHeight + UIConstants.bigOffset * 2,
            right: 0.0
        )
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let doubleImageView = PolkaswapDoubleSymbolView()
    let swapStubTitle: UILabel = {
        let label = UILabel()
        label.font = .p1Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 3
        label.textAlignment = .center
        return label
    }()

    let amountsLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorWhite()
        label.numberOfLines = 2
        return label
    }()

    let infoBackground = UIFactory.default.createInfoBackground()
    let infoViewsStackView: UIStackView = {
        let stackView = UIFactory.default.createVerticalStackView()
        stackView.alignment = .center
        stackView.spacing = 12
        return stackView
    }()

    let slippageView = UIFactory.default.createConfirmationMultiView()
    let swapRouteView: TitleMultiValueView = {
        let view = UIFactory.default.createMultiView()
        return view
    }()

    let apyView = UIFactory.default.createConfirmationMultiView()
    let networkFeeView = UIFactory.default.createConfirmationMultiView()
    let rewardTokenView = UIFactory.default.createConfirmationMultiView()

    private lazy var multiViews = [
        slippageView,
        apyView,
        networkFeeView,
        rewardTokenView
    ]

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backButton.rounded()
    }

    func bind(viewModel: LiquidityPoolSupplyViewModel) {
        slippageView.bind(viewModel: viewModel.slippageViewModel)
        apyView.bind(viewModel: viewModel.apyViewModel)
        rewardTokenView.bind(viewModel: viewModel.rewardTokenViewModel)
    }

    func bind(confirmViewModel: LiquidityPoolSupplyConfirmViewModel?) {
        amountsLabel.attributedText = confirmViewModel?.amountsText

        if let doubleImageViewModel = confirmViewModel?.doubleImageViewViewModel {
            doubleImageView.bind(viewModel: doubleImageViewModel)
        }
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeView.bindBalance(viewModel: feeViewModel)
    }

    // MARK: - Private methods

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)
        networkFeeView.titleLabel.text = R.string.localizable
            .commonNetworkFee(preferredLanguages: locale.rLanguages)
        confirmButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: locale.rLanguages)
        swapStubTitle.text = "Output is estimated. If the price changes more than 0.5% your transaction will revert."
        slippageView.titleLabel.text = R.string.localizable.polkaswapSettingsSlippageTitle(preferredLanguages: locale.rLanguages)
        apyView.titleLabel.text = "Strategic Bonus APY"
        rewardTokenView.titleLabel.text = "Rewards Payout In"
    }

    private func setupLayout() {
        func makeCommonConstraints(for view: UIView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }

        addSubview(navigationViewContainer)
        navigationViewContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.navigationBarHeight)
        }

        navigationViewContainer.addSubview(backButton)
        backButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(UIConstants.bigOffset)
            make.size.equalTo(Constants.backButtonSize)
        }

        navigationViewContainer.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        addSubview(contentView)
        addSubview(confirmButton)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationViewContainer.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        contentView.stackView.addArrangedSubview(infoBackground)

        infoViewsStackView.addArrangedSubview(doubleImageView)
        infoViewsStackView.addArrangedSubview(amountsLabel)
        infoViewsStackView.addArrangedSubview(swapStubTitle)

        infoBackground.addSubview(infoViewsStackView)
        makeCommonConstraints(for: infoBackground)
        infoViewsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        multiViews.forEach { view in
            infoViewsStackView.addArrangedSubview(view)
            makeCommonConstraints(for: view)
        }

        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
