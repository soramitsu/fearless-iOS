import UIKit

final class SwapTransactionDetailViewLayout: UIView {
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

    let statusView = UIFactory.default.createConfirmationMultiView()
    let fromView: TitleMultiValueView = {
        let view = UIFactory.default.createConfirmationMultiView()
        view.equalsLabelsWidth = true
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }()

    let dateView = UIFactory.default.createConfirmationMultiView()
    let networkFeeView = UIFactory.default.createConfirmationMultiView()

    private lazy var multiViews = [
        statusView,
        fromView,
        dateView,
        networkFeeView
    ]

    let closeButton: TriangularedButton = {
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

    func bind(viewModel: SwapTransactionViewModel) {
        amountsLabel.attributedText = viewModel.amountsText
        doubleImageView.bind(viewModel: viewModel.doubleImageViewViewModel)
        dateView.valueTop.text = viewModel.date
        statusView.valueTop.attributedText = viewModel.status
        fromView.valueTop.text = viewModel.walletName
        fromView.valueBottom.text = viewModel.address
        networkFeeView.bindBalance(viewModel: viewModel.networkFee)
    }

    // MARK: - Private methods

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)
        statusView.titleLabel.text = R.string.localizable
            .transactionDetailStatus(preferredLanguages: locale.rLanguages)
        fromView.titleLabel.text = R.string.localizable
            .transactionDetailsFrom(preferredLanguages: locale.rLanguages)
        fromView.valueTop.text = R.string.localizable
            .transactionDetailsSwapAwesomeWallet(preferredLanguages: locale.rLanguages)
        networkFeeView.titleLabel.text = R.string.localizable
            .commonNetworkFee(preferredLanguages: locale.rLanguages)
        closeButton.imageWithTitleView?.title = R.string.localizable
            .commonClose(preferredLanguages: locale.rLanguages)
        swapStubTitle.text = R.string.localizable
            .polkaswapConfirmationSwapStub(preferredLanguages: locale.rLanguages)
        dateView.titleLabel.text = R.string.localizable
            .transactionDetailDate(preferredLanguages: locale.rLanguages)
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
        addSubview(closeButton)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationViewContainer.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(closeButton.snp.bottom).offset(UIConstants.bigOffset)
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

        closeButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }
}
