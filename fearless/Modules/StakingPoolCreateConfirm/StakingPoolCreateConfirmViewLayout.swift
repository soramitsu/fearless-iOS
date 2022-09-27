import UIKit

final class StakingPoolCreateConfirmViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        bar.backButton.layer.cornerRadius = bar.backButton.frame.size.height / 2
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorGray()
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }()

    let infoBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconPoolStaking()
        return imageView
    }()

    let infoViewsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    lazy var accountView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var amountView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var poolIdView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var depositorView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var rootView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var nominatorView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var stateTogglerView: TitleMultiValueView = {
        createMultiView()
    }()

    let feeView: NetworkFeeView = {
        let view = NetworkFeeView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.tokenLabel.font = .h5Title
        view.tokenLabel.textColor = .white
        view.fiatLabel?.font = .p1Paragraph
        view.fiatLabel?.textColor = R.color.colorStrokeGray()
        return view
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    lazy var multiViews: [TitleMultiValueView] = {
        [
            accountView,
            amountView,
            poolIdView,
            depositorView,
            rootView,
            nominatorView,
            stateTogglerView
        ]
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
    }

    func bind(confirmViewModel: StakingPoolCreateConfirmViewModel) {
        amountLabel.attributedText = confirmViewModel.amount
        accountView.valueBottom.text = confirmViewModel.rootName
        amountView.valueTop.text = confirmViewModel.amountString
        amountView.valueBottom.text = confirmViewModel.price
        poolIdView.valueTop.text = confirmViewModel.poolId
        depositorView.valueTop.text = confirmViewModel.rootName
        rootView.valueTop.text = confirmViewModel.rootName
        nominatorView.valueTop.text = confirmViewModel.nominatorName
        stateTogglerView.valueTop.text = confirmViewModel.stateTogglerName
    }

    private func configure() {
        func configure(view: TitleMultiValueView) {
            view.valueBottom.lineBreakMode = .byTruncatingMiddle
            view.valueBottom.textAlignment = .right
            view.valueTop.textAlignment = .right
            view.borderView.isHidden = true
        }

        multiViews.forEach { configure(view: $0) }

        feeView.borderType = .none
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        ))
        accountView.titleLabel.text = R.string.localizable.transactionDetailsFrom(
            preferredLanguages: locale.rLanguages
        )
        amountView.titleLabel.text = R.string.localizable.walletSendAssetTitle(
            preferredLanguages: locale.rLanguages
        )
        accountView.valueTop.text = R.string.localizable.stakingPoolCreateManagementAccount(
            preferredLanguages: locale.rLanguages
        )
        poolIdView.titleLabel.text = R.string.localizable.stakingPoolCreatePoolId(
            preferredLanguages: locale.rLanguages
        )
        depositorView.titleLabel.text = R.string.localizable.stakingPoolCreateDepositor(
            preferredLanguages: locale.rLanguages
        )
        rootView.titleLabel.text = R.string.localizable.stakingPoolCreateRoot(
            preferredLanguages: locale.rLanguages
        )
        nominatorView.titleLabel.text = R.string.localizable.stakingPoolCreateNominator(
            preferredLanguages: locale.rLanguages
        )
        stateTogglerView.titleLabel.text = R.string.localizable.stakingPoolCreateStateToggler(
            preferredLanguages: locale.rLanguages
        )
        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )
        continueButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        func makeMultiViewConstraints(view: TitleMultiValueView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(UIConstants.cellHeight)
            }
        }

        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(continueButton)

        contentView.stackView.addArrangedSubview(iconImageView)
        contentView.stackView.addArrangedSubview(amountLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        infoBackground.addSubview(infoViewsStackView)
        multiViews.forEach { infoViewsStackView.addArrangedSubview($0) }
        infoViewsStackView.addArrangedSubview(feeView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(continueButton.snp.top).offset(-UIConstants.bigOffset)
        }

        continueButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        infoBackground.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoViewsStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview()
        }

        multiViews.forEach { makeMultiViewConstraints(view: $0) }

        feeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }
    }

    private func createMultiView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = .white
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }
}
