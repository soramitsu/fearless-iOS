import UIKit
import SnapKit

final class PolkaswapAdjustmentViewLayout: UIView {
    private enum Constants {
        static let navigationBarHeight: CGFloat = 56.0
        static let backButtonSize = CGSize(width: 32, height: 32)
        static let imageWidth: CGFloat = 12
        static let imageHeight: CGFloat = 12
        static let imageVerticalPosition: CGFloat = 2
    }

    var keyboardAdoptableConstraint: Constraint?

    // MARK: navigation

    let navigationViewContainer = UIView()

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    let polkaswapImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.polkaswap()
        return imageView
    }()

    let marketButton = MarketButton()

    // MARK: content

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let swapFromInputView = SelectableAmountInputView(type: .swapSend)
    let swapToInputView = SelectableAmountInputView(type: .swapReceive)
    let switchSwapButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconSwitch(), for: .normal)
        return button
    }()

    let minMaxReceivedView = UIFactory.default.createMultiView()
    let swapRouteView = UIFactory.default.createMultiView()
    let fromPerToPriceView = UIFactory.default.createMultiView()
    let toPerFromPriceView = UIFactory.default.createMultiView()
    let liquidityProviderFeeView = UIFactory.default.createMultiView()
    let networkFeeView = UIFactory.default.createMultiView()

    private lazy var multiViews = [
        minMaxReceivedView,
        swapRouteView,
        fromPerToPriceView,
        toPerFromPriceView,
        liquidityProviderFeeView,
        networkFeeView
    ]

    let previewButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    // MARK: - Lifecycle

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

    // MARK: - Public methods

    func bindSwapFrom(assetViewModel: AssetBalanceViewModelProtocol?) {
        swapFromInputView.bind(viewModel: assetViewModel)
    }

    func bindSwapTo(assetViewModel: AssetBalanceViewModelProtocol?) {
        swapToInputView.bind(viewModel: assetViewModel)
    }

    func bindDetails(viewModel: PolkaswapAdjustmentDetailsViewModel?) {
        guard let viewModel = viewModel else {
            multiViews.forEach { $0.isHidden = true }
            return
        }
        minMaxReceivedView.bindBalance(viewModel: viewModel.minMaxReceiveVieModel)
        swapRouteView.valueTop.text = viewModel.route
        fromPerToPriceView.titleLabel.text = viewModel.fromPerToTitle
        fromPerToPriceView.valueTop.text = viewModel.fromPerToValue
        toPerFromPriceView.titleLabel.text = viewModel.toPerFromTitle
        toPerFromPriceView.valueTop.text = viewModel.toPerFromValue
        liquidityProviderFeeView.bindBalance(viewModel: viewModel.liqudityProviderFeeVieModel)
        multiViews.forEach { $0.isHidden = false }
    }

    func bind(swapVariant: SwapVariant) {
        var text: String
        switch swapVariant {
        case .desiredInput:
            text = R.string.localizable
                .polkaswapMinReceived(preferredLanguages: locale.rLanguages)
        case .desiredOutput:
            text = R.string.localizable
                .polkaswapMaxReceived(preferredLanguages: locale.rLanguages)
        }
        setInfoImage(for: minMaxReceivedView.titleLabel, text: text)
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationViewContainer)
        setupNavigationLayout(for: navigationViewContainer)
        setupContentsLayout()
    }

    private func setupNavigationLayout(for container: UIView) {
        container.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.navigationBarHeight)
        }

        container.addSubview(backButton)
        container.addSubview(polkaswapImageView)
        container.addSubview(marketButton)

        backButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(UIConstants.bigOffset)
            make.size.equalTo(Constants.backButtonSize)
        }

        polkaswapImageView.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(backButton.snp.trailing).offset(UIConstants.defaultOffset)
        }

        marketButton.snp.makeConstraints { make in
            make.height.equalTo(Constants.backButtonSize.height)
            make.centerY.equalToSuperview()
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.greaterThanOrEqualTo(polkaswapImageView.snp.trailing).offset(UIConstants.defaultOffset)
        }
    }

    private func setupContentsLayout() {
        addSubview(contentView)
        addSubview(previewButton)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationViewContainer.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(previewButton.snp.top).offset(-UIConstants.bigOffset)
        }

        previewButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().inset(UIConstants.bigOffset).constraint
            make.height.equalTo(UIConstants.actionHeight)
        }

        let switchIntutsView = createSwitchInputsView()
        contentView.stackView.addArrangedSubview(switchIntutsView)
        switchIntutsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        let feesView = createFeesView()
        contentView.stackView.addArrangedSubview(feesView)
        feesView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
    }

    private func createSwitchInputsView() -> UIView {
        let container = UIView()
        container.addSubview(swapFromInputView)
        container.addSubview(swapToInputView)
        container.addSubview(switchSwapButton)

        swapFromInputView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        swapToInputView.snp.makeConstraints { make in
            make.top.equalTo(swapFromInputView.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.bottom.equalToSuperview()
        }

        switchSwapButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(swapFromInputView.snp.bottom).offset(UIConstants.defaultOffset / 2)
        }

        return container
    }

    private func createFeesView() -> UIView {
        func makeCommonConstraints(for view: UIView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }

        let container = UIFactory.default.createVerticalStackView()

        multiViews.forEach {
            container.addArrangedSubview($0)
            makeCommonConstraints(for: $0)
            $0.isHidden = true
            $0.titleLabel.isUserInteractionEnabled = true
        }

        return container
    }

    private func createMultiView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.borderView.borderType = .none
        view.titleLabel.font = .p2Paragraph
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h6Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p2Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }

    private func applyLocalization() {
        swapFromInputView.locale = locale
        swapToInputView.locale = locale
        marketButton.locale = locale

        swapRouteView.titleLabel.text = R.string.localizable
            .polkaswapConfirmationRouteStub(preferredLanguages: locale.rLanguages)

        let texts = [
            R.string.localizable
                .polkaswapLiquidityProviderFee(preferredLanguages: locale.rLanguages),
            R.string.localizable
                .polkaswapNetworkFee(preferredLanguages: locale.rLanguages)
        ]

        [
            liquidityProviderFeeView.titleLabel,
            networkFeeView.titleLabel
        ].enumerated().forEach { index, label in
            setInfoImage(for: label, text: texts[index])
        }

        previewButton.imageWithTitleView?.title = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)
    }

    private func setInfoImage(for label: UILabel, text: String) {
        let attributedString = NSMutableAttributedString(string: text)

        let imageAttachment = NSTextAttachment()
        imageAttachment.image = R.image.iconInfoFilled()
        imageAttachment.bounds = CGRect(
            x: 0,
            y: -Constants.imageVerticalPosition,
            width: Constants.imageWidth,
            height: Constants.imageHeight
        )

        let imageString = NSAttributedString(attachment: imageAttachment)
        attributedString.append(imageString)

        label.attributedText = attributedString
    }
}
