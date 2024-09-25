import UIKit

final class CrossChainSwapConfirmViewLayout: UIView {
    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

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
        label.font = .h3Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let swapAmountInfoView = SwapAmountInfoView()
    let infoViewsStackView = UIFactory.default.createVerticalStackView()

    let originNetworkFeeView = createMultiView()
    let minReceivedView = createMultiView()
    let routeView = createMultiView()
    let sendRatioView = createMultiView()
    let receiveRatioView = createMultiView()

    private lazy var multiViews = [
        minReceivedView,
        routeView,
        sendRatioView,
        receiveRatioView,
        originNetworkFeeView
    ]

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

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

    func bind(doubleImageViewModel: PolkaswapDoubleSymbolViewModel) {
        doubleImageView.bind(viewModel: doubleImageViewModel)
    }

    func bind(swapAmountInfoViewModel: SwapAmountInfoViewModel) {
        swapAmountInfoView.bind(viewModel: swapAmountInfoViewModel)
    }

    func bind(viewModel: CrossChainSwapViewModel?) {
        [minReceivedView, routeView, sendRatioView, receiveRatioView, originNetworkFeeView].forEach { $0.isHidden = viewModel == nil }

        minReceivedView.bindBalance(viewModel: viewModel?.minimumReceived)
        routeView.valueTop.text = viewModel?.route
        sendRatioView.valueTop.text = viewModel?.sendTokenRatio
        receiveRatioView.valueTop.text = viewModel?.receiveTokenRatio
        sendRatioView.titleLabel.text = viewModel?.sendTokenRatioTitle
        receiveRatioView.titleLabel.text = viewModel?.receiveTokenRatioTitle
        originNetworkFeeView.bindBalance(viewModel: viewModel?.fee)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        originNetworkFeeView.bindBalance(viewModel: feeViewModel)
    }

    // MARK: - Private methods

    private func applyLocalization() {
        confirmButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: locale.rLanguages)

        titleLabel.text = R.string.localizable.xcmTitle(preferredLanguages: locale.rLanguages)
        originNetworkFeeView.titleLabel.text = R.string.localizable.xcmOriginNetworkFeeTitle(preferredLanguages: locale.rLanguages)
        minReceivedView.titleLabel.text = R.string.localizable.polkaswapMinReceived(preferredLanguages: locale.rLanguages)
        routeView.titleLabel.text = R.string.localizable.polkaswapConfirmationRouteStub(preferredLanguages: locale.rLanguages)
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

        contentView.stackView.addArrangedSubview(doubleImageView)
        contentView.stackView.addArrangedSubview(swapStubTitle)
        contentView.stackView.addArrangedSubview(swapAmountInfoView)
        contentView.stackView.addArrangedSubview(infoViewsStackView)

        multiViews.forEach { view in
            infoViewsStackView.addArrangedSubview(view)
            makeCommonConstraints(for: view)
        }

        infoViewsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    private static func createMultiView() -> TitleMultiValueView {
        let view = UIFactory.default.createMultiView()
        view.titleLabel.font = .h6Title
        view.valueTop.font = .h5Title
        return view
    }
}
