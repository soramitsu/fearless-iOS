import UIKit
import SnapKit

final class PolkaswapAdjustmentViewLayout: UIView {
    private enum Constants {
        static let navigationBarHeight: CGFloat = 56.0
        static let backButtonSize = CGSize(width: 32, height: 32)
        static let imageWidth: CGFloat = 12
        static let imageHeight: CGFloat = 12
        static let imageVerticalPosition: CGFloat = 2
        static let disclaimerMinHeight: CGFloat = 42.0
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
    let swapRouteView: TitleMultiValueView = {
        let view = UIFactory.default.createMultiView()
        view.isHidden = true
        return view
    }()

    let fromPerToPriceView = UIFactory.default.createMultiView()
    let toPerFromPriceView = UIFactory.default.createMultiView()
    let liquidityProviderFeeView = UIFactory.default.createMultiView()
    let networkFeeView = UIFactory.default.createMultiView()

    private lazy var multiViews = [
        minMaxReceivedView,
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

    let disclaimerView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.iconImage = R.image.iconWarning()
        view.titleLabel.font = .capsTitle
        view.titleLabel.textColor = R.color.colorOrange()
        view.subtitleLabel?.font = .p3Paragraph
        view.subtitleLabel?.textColor = R.color.colorWhite50()
        view.borderWidth = 1
        view.strokeColor = R.color.colorWhite8()!
        view.iconInCenterY = true
        view.layout = .smallIconTitleSubtitleButton
        view.isUserInteractionEnabled = true
        view.contentView?.isUserInteractionEnabled = true
        view.backgroundView?.isUserInteractionEnabled = true
        view.actionButton?.triangularedView?.fillColor = R.color.colorOrange()!
        view.actionButton?.triangularedView?.highlightedFillColor = R.color.colorOrange()!
        view.actionButton?.imageWithTitleView?.titleFont = .p3Paragraph
        return view
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

        let bottomContainer = createBottomContainer()
        addSubview(bottomContainer)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationViewContainer.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(bottomContainer.snp.top).offset(-UIConstants.bigOffset)
        }

        bottomContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            keyboardAdoptableConstraint = make.bottom.equalToSuperview().inset(UIConstants.bigOffset).constraint
        }

        let switchInputsView = createSwitchInputsView()
        contentView.stackView.addArrangedSubview(switchInputsView)
        switchInputsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        let feesView = createFeesView()
        contentView.stackView.addArrangedSubview(feesView)
        feesView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
        layoutIfNeeded()
    }

    private func createSwitchInputsView() -> UIView {
        let container = UIView()
        container.addSubview(swapFromInputView)
        container.addSubview(swapToInputView)
        container.addSubview(switchSwapButton)

        swapFromInputView.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        swapToInputView.snp.makeConstraints { make in
            make.top.equalTo(swapFromInputView.snp.bottom).offset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview()
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

        disclaimerView.title = "DISCLAIMER"
        disclaimerView.subtitle = "Please read before continuing to use Polkaswap"
        disclaimerView.actionButton?.imageWithTitleView?.title = "Read"
    }

    private func createBottomContainer() -> UIView {
        let container = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
        container.addArrangedSubview(disclaimerView)
        container.addArrangedSubview(previewButton)

        disclaimerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(Constants.disclaimerMinHeight)
        }

        previewButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.actionHeight)
        }

        return container
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
