import UIKit

final class PolkaswapSwapConfirmationViewLayout: UIView {
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
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let doubleImageView = PolkaswapDoubleSymbolView()
    let swapStubTitle: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = R.color.colorStrokeGray()
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
    let infoViewsStackView = UIFactory.default.createVerticalStackView()

    let fromPerToPriceView = UIFactory.default.createMultiView()
    let toPerFromPriceView = UIFactory.default.createMultiView()
    let minMaxReceiveView = UIFactory.default.createMultiView()
    let swapRouteView = UIFactory.default.createMultiView()
    let liquitityProviderFeeView = UIFactory.default.createMultiView()
    let networkFeeView = UIFactory.default.createMultiView()

    private lazy var multiViews = [
        fromPerToPriceView,
        toPerFromPriceView,
        minMaxReceiveView,
        swapRouteView,
        liquitityProviderFeeView,
        networkFeeView
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

    func bind(viewModel: PolkaswapSwapConfirmationViewModel) {
        amountsLabel.attributedText = viewModel.amountsText
        doubleImageView.bind(viewModel: viewModel.doubleImageViewViewModel)

        fromPerToPriceView.titleLabel.text = viewModel.fromPerToTitle
        toPerFromPriceView.titleLabel.text = viewModel.toPerFromTitle

        fromPerToPriceView.valueTop.text = viewModel.fromPerToPrice
        toPerFromPriceView.valueTop.text = viewModel.toPerFromPrice
        minMaxReceiveView.bindBalance(viewModel: viewModel.minMaxReceive)
        swapRouteView.valueTop.attributedText = viewModel.swapRoute
        liquitityProviderFeeView.bindBalance(viewModel: viewModel.liquitityProviderFee)
        networkFeeView.bindBalance(viewModel: viewModel.networkFee)
    }

    // MARK: - Private methods

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)
        minMaxReceiveView.titleLabel.text = R.string.localizable
            .polkaswapMinReceived(preferredLanguages: locale.rLanguages)
        swapRouteView.titleLabel.text = R.string.localizable
            .polkaswapConfirmationRouteStub(preferredLanguages: locale.rLanguages)
        liquitityProviderFeeView.titleLabel.text = R.string.localizable
            .polkaswapLiquidityProviderFee(preferredLanguages: locale.rLanguages)
        networkFeeView.titleLabel.text = R.string.localizable
            .commonNetworkFee(preferredLanguages: locale.rLanguages)
        confirmButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: locale.rLanguages)
        swapStubTitle.text = R.string.localizable
            .polkaswapConfirmationSwapStub(preferredLanguages: locale.rLanguages)
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
            make.bottom.equalTo(confirmButton.snp.bottom).offset(UIConstants.bigOffset)
        }

        contentView.stackView.addArrangedSubview(doubleImageView)
        contentView.stackView.addArrangedSubview(swapStubTitle)
        contentView.stackView.addArrangedSubview(amountsLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

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
