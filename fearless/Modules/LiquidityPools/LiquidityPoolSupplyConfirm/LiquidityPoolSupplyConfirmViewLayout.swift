import UIKit

final class LiquidityPoolSupplyConfirmViewLayout: UIView {
    private enum Constants {
        static let navigationBarHeight: CGFloat = 56.0
        static let backButtonSize = CGSize(width: 32, height: 32)
        static let imageWidth: CGFloat = 12
        static let imageHeight: CGFloat = 12
        static let imageVerticalPosition: CGFloat = 2
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

    let doubleImageView = PolkaswapDoubleSymbolView(imageSize: CGSize(width: 64, height: 64), mode: .filled)
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
        button.isEnabled = true
        button.applyEnabledStyle()
        return button
    }()

    let apyInfoButton: UIButton = {
        let button = UIButton()
        button.isUserInteractionEnabled = false
        button.setImage(R.image.iconInfoFilled(), for: .normal)
        return button
    }()

    let tokenIconImageView = UIImageView()

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

        viewModel.rewardTokenIconViewModel?.loadImage(
            on: tokenIconImageView,
            targetSize: CGSize(width: 16, height: 16),
            animated: true
        )
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
        titleLabel.text = "Confirm Liquidity"
        confirmButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: locale.rLanguages)
        swapStubTitle.text = "Output is estimated. If the price changes more than 0.5% your transaction will revert."
        slippageView.titleLabel.text = "Slippage"
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

//        apyView.addSubview(apyInfoButton)
//
//        apyInfoButton.snp.makeConstraints { make in
//            make.leading.equalTo(apyView.titleLabel.snp.trailing).offset(4)
//            make.centerY.equalToSuperview()
//            make.size.equalTo(12)
//        }

        rewardTokenView.addSubview(tokenIconImageView)

        rewardTokenView.valueTop.snp.makeConstraints { make in
            make.leading.equalTo(tokenIconImageView.snp.trailing).offset(4)
        }
        tokenIconImageView.snp.makeConstraints { make in
            make.size.equalTo(16)
            make.centerY.equalToSuperview()
        }

        let texts = [
            R.string.localizable
                .polkaswapNetworkFee(preferredLanguages: locale.rLanguages),
            "Strategic Bonus APY"
        ]

        [
            networkFeeView.titleLabel,
            apyView.titleLabel
        ].enumerated().forEach { index, label in
            setInfoImage(for: label, text: texts[index])
        }
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
        attributedString.append(NSAttributedString(string: " "))
        attributedString.append(imageString)

        label.attributedText = attributedString
    }
}
