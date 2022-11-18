import UIKit
import SoraFoundation

// swiftlint:disable type_body_length
final class StakingPoolManagementViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
        bar.backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        bar.backButton.layer.cornerRadius = bar.backButton.frame.size.height / 2
        bar.backgroundColor = R.color.colorBlack19()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let totalStakeLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorStrokeGray()
        label.textAlignment = .center
        label.numberOfLines = 0
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

    let infoStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

    let balanceView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        return view
    }()

    let unstakingView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        return view
    }()

    let poolInfoView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        return view
    }()

    let reedeemDelayView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        return view
    }()

    let stakeMoreButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    let unstakeButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    let alertsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.defaultOffset)

    lazy var selectValidatorsView: DetailsTriangularedView = {
        createAlertView()
    }()

    lazy var claimView: DetailsTriangularedView = {
        createAlertView()
    }()

    lazy var redeemView: DetailsTriangularedView = {
        createAlertView()
    }()

    let optionsButton: UIButton = {
        let optionsButton = UIButton()
        optionsButton.setImage(R.image.iconHorMore(), for: .normal)
        optionsButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        return optionsButton
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
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        optionsButton.rounded()
        navigationBar.backButton.rounded()
    }

    // MARK: - Public methods

    func bind(poolName: String?) {
        poolInfoView.bind(viewModel: poolName)
    }

    func bind(balanceViewModel: BalanceViewModelProtocol?) {
        balanceView.bind(viewModel: balanceViewModel)
    }

    func bind(unstakeBalanceViewModel: BalanceViewModelProtocol?) {
        unstakingView.bind(viewModel: unstakeBalanceViewModel)
    }

    func bind(stakedAmountString: NSAttributedString) {
        totalStakeLabel.attributedText = stakedAmountString
    }

    func bind(redeemDelayViewModel: LocalizableResource<String>?) {
        reedeemDelayView.bind(viewModel: redeemDelayViewModel?.value(for: locale))
    }

    func bind(claimableViewModel: BalanceViewModelProtocol?) {
        claimView.isHidden = claimableViewModel == nil
        claimView.subtitle = claimableViewModel?.amount
    }

    func bind(redeemableViewModel: BalanceViewModelProtocol?) {
        redeemView.isHidden = redeemableViewModel == nil
        redeemView.subtitle = redeemableViewModel?.amount
    }

    func bind(viewModel: StakingPoolManagementViewModel?) {
        stakeMoreButton.isHidden = viewModel?.stakeMoreButtonVisible == false
        unstakeButton.isHidden = viewModel?.unstakeButtonVisible == false
    }

    func setSelectValidatorsAlert(visible: Bool) {
        selectValidatorsView.isHidden = !visible
    }

    // MARK: - Private methods

    private func createAlertView() -> DetailsTriangularedView {
        let view = DetailsTriangularedView()
        view.actionColor = R.color.colorPink1()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.iconImage = R.image.iconAttention()
        view.titleLabel.font = .h6Title
        view.titleLabel.textColor = R.color.colorPink1()!
        view.subtitleLabel?.font = .p1Paragraph
        view.subtitleLabel?.textColor = R.color.colorTransparentText()
        view.layout = .smallIconTitleSubtitleButton
        view.isUserInteractionEnabled = true
        view.contentView?.isUserInteractionEnabled = true
        view.backgroundView?.isUserInteractionEnabled = true
        view.isHidden = true
        return view
    }

    // swiftlint:disable function_body_length
    private func setupLayout() {
        func makeDefaultConstraints(for view: UIView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(UIConstants.cellHeight)
            }
        }

        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(stakeMoreButton)
        addSubview(unstakeButton)

        navigationBar.setRightViews([optionsButton])

        contentView.stackView.addArrangedSubview(totalStakeLabel)
        contentView.stackView.addArrangedSubview(alertsStackView)
        contentView.stackView.addArrangedSubview(infoBackground)
        infoBackground.addSubview(infoStackView)

        infoStackView.addArrangedSubview(balanceView)
        infoStackView.addArrangedSubview(unstakingView)
        infoStackView.addArrangedSubview(poolInfoView)
        infoStackView.addArrangedSubview(reedeemDelayView)

        alertsStackView.addArrangedSubview(selectValidatorsView)
        alertsStackView.addArrangedSubview(claimView)
        alertsStackView.addArrangedSubview(redeemView)

        optionsButton.snp.makeConstraints { make in
            make.size.equalTo(32)
        }

        alertsStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(stakeMoreButton.snp.top).offset(UIConstants.bigOffset)
        }

        infoBackground.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        stakeMoreButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
        }

        unstakeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalTo(stakeMoreButton.snp.trailing).offset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            make.width.equalTo(stakeMoreButton.snp.width)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
        }

        [
            balanceView,
            unstakingView,
            poolInfoView,
            reedeemDelayView,
            claimView,
            redeemView
        ].forEach { makeDefaultConstraints(for: $0) }

        selectValidatorsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.amountViewHeight)
        }
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.stakingPoolInfoTitle(
            preferredLanguages: locale.rLanguages
        ))
        stakeMoreButton.imageWithTitleView?.title = R.string.localizable.stakingBondMore_v190(
            preferredLanguages: locale.rLanguages
        )
        unstakeButton.imageWithTitleView?.title = R.string.localizable.stakingUnbond_v190(
            preferredLanguages: locale.rLanguages
        )
        balanceView.titleLabel.text = R.string.localizable.walletBalanceAvailable(
            preferredLanguages: locale.rLanguages
        )
        unstakingView.titleLabel.text = R.string.localizable.walletBalanceUnbonding_v190(
            preferredLanguages: locale.rLanguages
        )
        poolInfoView.titleLabel.text = R.string.localizable.stakingPoolInfoTitle(
            preferredLanguages: locale.rLanguages
        )
        reedeemDelayView.titleLabel.text = R.string.localizable.poolStakingRedeemDelayTitle(
            preferredLanguages: locale.rLanguages
        )

        selectValidatorsView.title = R.string.localizable.stakingPoolManagementSelectValidatorsTitle(
            preferredLanguages: locale.rLanguages
        )
        selectValidatorsView.subtitle = R.string.localizable.stakingPoolManagementSelectValidatorsSubtitle(
            preferredLanguages: locale.rLanguages
        )
        selectValidatorsView.actionButton?.imageWithTitleView?.title = R.string.localizable.commonSelect(
            preferredLanguages: locale.rLanguages
        )
        claimView.title = R.string.localizable.poolStakingManagementClaimTitle(
            preferredLanguages: locale.rLanguages
        )
        redeemView.title = R.string.localizable.poolStakingManagementRedeemTitle(
            preferredLanguages: locale.rLanguages
        )

        claimView.actionButton?.imageWithTitleView?.title = R.string.localizable.poolStakingClaimAmountTitle(
            "", preferredLanguages: locale.rLanguages
        )
        redeemView.actionButton?.imageWithTitleView?.title = R.string.localizable.stakingRedeem(
            preferredLanguages: locale.rLanguages
        )
    }
}
