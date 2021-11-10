import UIKit
import BetterSegmentedControl

final class CrowdloanContributionSetupViewLayout: UIView {
    enum View {
        case contributionTitleLabel
        case amountInputView
        case hintView
        case networkFeeView
        case ethereumAddressForRewardView(Bool)
        case estimatedRewardView(Bool)
        case bonusView(Bool)
        case leasingPeriodView
        case raisedView
        case timeleftView
        case learnMoreView(Bool)
        case actionButton
        case contributionTypeView
        case privacy

        func draw(in view: CrowdloanContributionSetupViewLayout) {
            switch self {
            case .contributionTitleLabel:
                view.drawContributionTitleLabel()
            case .amountInputView:
                view.drawAmountInputView()
            case .hintView:
                view.drawHintView()
            case .networkFeeView:
                view.drawNetworkFeeView()
            case let .ethereumAddressForRewardView(visible):
                visible ? view.drawEthereumAddressForRewardView() : ()
            case let .estimatedRewardView(visible):
                visible ? view.drawEstimatedRewardView() : ()
            case let .bonusView(visible):
                visible ? view.drawBonusView() : ()
            case .leasingPeriodView:
                view.drawLeasingPeriodView()
            case .raisedView:
                view.drawRaisedView()
            case .timeleftView:
                view.drawTimeleftView()
            case let .learnMoreView(visible):
                visible ? view.drawLearnMoreView() : ()
            case .actionButton:
                view.drawActionButton()
            case .contributionTypeView:
                view.drawContributionTypeView()
            case .privacy:
                view.drawPrivacyView()
            }
        }
    }

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let contributionTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()!
        label.font = .h4Title
        return label
    }()

    private func drawContributionTitleLabel() {
        contentView.stackView.addArrangedSubview(contributionTitleLabel)
        contributionTitleLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }
        contentView.stackView.setCustomSpacing(16.0, after: contributionTitleLabel)
    }

    let amountInputView = UIFactory.default.createAmountInputView(filled: false)

    private func drawAmountInputView() {
        contentView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(72.0)
        }
        contentView.stackView.setCustomSpacing(16.0, after: amountInputView)
    }

    let hintView = UIFactory.default.createHintView()

    private func drawHintView() {
        contentView.stackView.addArrangedSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }
        contentView.stackView.setCustomSpacing(16.0, after: hintView)
    }

    let networkFeeView = NetworkFeeView()

    private func drawNetworkFeeView() {
        contentView.stackView.addArrangedSubview(networkFeeView)
        networkFeeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }
    }

    lazy var ethereumAddressForRewardView: EthereumAddressForRewardView = {
        EthereumAddressForRewardView()
    }()

    private func drawEthereumAddressForRewardView() {
        contentView.stackView.addArrangedSubview(ethereumAddressForRewardView)
    }

    lazy var estimatedRewardView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.text = R.string.localizable.crowdloanReward(preferredLanguages: locale.rLanguages)
        return view
    }()

    private func drawEstimatedRewardView() {
        contentView.stackView.addArrangedSubview(estimatedRewardView)
        estimatedRewardView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }
    }

    lazy var bonusView: RowView<TitleValueSelectionView> = {
        let view = RowView(contentView: TitleValueSelectionView(), preferredHeight: 48.0)
        view.borderView.strokeWidth = 1.0

        view.rowContentView.titleLabel.text = R.string.localizable.commonBonus(
            preferredLanguages: locale.rLanguages
        )

        view.rowContentView.iconView.image = R.image.iconBonus()
        return view
    }()

    private func drawBonusView() {
        contentView.stackView.addArrangedSubview(bonusView)
        bonusView.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        bonusView.contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )
    }

    let leasingPeriodView = TitleMultiValueView()

    private func drawLeasingPeriodView() {
        contentView.stackView.addArrangedSubview(leasingPeriodView)
        leasingPeriodView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }
    }

    let crowdloanInfoTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()!
        label.font = .h4Title
        return label
    }()

    let raisedView = TitleMultiValueView()

    private func drawRaisedView() {
        contentView.stackView.addArrangedSubview(raisedView)
        raisedView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }
    }

    let timeLeftVew = TitleValueView()

    private func drawTimeleftView() {
        contentView.stackView.addArrangedSubview(timeLeftVew)
        timeLeftVew.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }
    }

    lazy var learnMoreView: LearnMoreView = {
        UIFactory.default.createLearnMoreView()
    }()

    private func drawLearnMoreView() {
        contentView.stackView.addArrangedSubview(learnMoreView)
        learnMoreView.snp.makeConstraints { make in
            make.width.equalTo(self)
            make.height.equalTo(48.0)
        }
    }

    // MARK: Action button

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    private func drawActionButton() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }
    }

    let privacyView: UIView = {
        UIView()
    }()

    let termsSwitchView: UISwitch = {
        let switchView = UISwitch()
        switchView.onTintColor = R.color.colorAccent()
        return switchView
    }()

    let termsLabel: UILabel = {
        let label = UILabel()
        label.isUserInteractionEnabled = true
        label.font = .p1Paragraph
        label.numberOfLines = 2
        return label
    }()

    private func drawPrivacyView() {
        contentView.stackView.addArrangedSubview(privacyView)
        privacyView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.cellHeight)
        }

        privacyView.addSubview(termsSwitchView)
        termsSwitchView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }

        privacyView.addSubview(termsLabel)
        termsLabel.snp.makeConstraints { make in
            make.leading.equalTo(termsSwitchView.snp.trailing).offset(UIConstants.bigOffset)
            make.trailing.centerY.equalToSuperview()
        }

        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: privacyView)
    }

    // MARK: Contribution type view

    lazy var contributionTypeView = UIView()

    lazy var contributionTypeLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorAlmostWhite()
        label.font = .h4Title
        return label
    }()

    lazy var contributionTypeControl: BetterSegmentedControl = UIFactory.default.createFearlessSegmentedControl()

    lazy var contributionTypeHintView: HintView = UIFactory.default.createHintView()

    private func drawContributionTypeView() {
        contentView.stackView.addArrangedSubview(contributionTypeView)

        contributionTypeView.addSubview(contributionTypeLabel)
        contributionTypeView.addSubview(contributionTypeControl)
        contributionTypeView.addSubview(contributionTypeHintView)

        contributionTypeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.defaultOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }

        contributionTypeControl.snp.makeConstraints { make in
            make.top.equalTo(contributionTypeLabel)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.greaterThanOrEqualTo(contributionTypeLabel.snp.trailing).offset(UIConstants.defaultOffset)
        }

        contributionTypeHintView.snp.makeConstraints { make in
            make.leading.equalTo(contributionTypeLabel)
            make.trailing.equalTo(contributionTypeControl)
            make.top.equalTo(contributionTypeLabel).offset(UIConstants.defaultOffset)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: contributionTypeView)
    }

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(with views: [CrowdloanContributionSetupViewLayout.View]) {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        views.forEach { view in
            view.draw(in: self)
        }

        contentView.scrollBottomOffset = 2 * UIConstants.horizontalInset + UIConstants.actionHeight

        applyLocalization()
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol?) {
        guard let assetViewModel = assetViewModel else {
            return
        }

        amountInputView.priceText = assetViewModel.price

        if let balance = assetViewModel.balance {
            amountInputView.balanceText = R.string.localizable.commonAvailableFormat(
                balance,
                preferredLanguages: locale.rLanguages
            )
        } else {
            amountInputView.balanceText = nil
        }

        amountInputView.assetIcon = assetViewModel.icon

        let symbol = assetViewModel.symbol.uppercased()
        amountInputView.symbol = symbol

        hintView.titleLabel.text = R.string.localizable.crowdloanUnlockHint(
            symbol,
            preferredLanguages: locale.rLanguages
        )
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeView.bind(viewModel: feeViewModel)
    }

    func bind(crowdloanViewModel: CrowdloanContributionSetupViewModelProtocol) {
        leasingPeriodView.valueTop.text = crowdloanViewModel.leasingPeriod
        leasingPeriodView.valueBottom.text = crowdloanViewModel.leasingCompletionDate

        raisedView.valueTop.text = crowdloanViewModel.raisedProgress
        raisedView.valueBottom.text = crowdloanViewModel.raisedPercentage

        timeLeftVew.valueLabel.text = crowdloanViewModel.remainedTime

        if let learnMore = crowdloanViewModel.learnMore {
            learnMoreView.bind(viewModel: learnMore)
        }
    }

    func bind(estimatedReward: String?) {
        guard let estimatedReward = estimatedReward else {
            return
        }

        estimatedRewardView.valueLabel.text = estimatedReward
    }

    func bind(bonus: String?) {
        guard let bonus = bonus else {
            return
        }

        bonusView.rowContentView.detailsLabel.text = bonus
    }

    func bind(to defaultViewModel: CrowdloanContributionSetupViewModel) {
        bind(feeViewModel: defaultViewModel.fee)
        bind(bonus: defaultViewModel.bonus)
        bind(estimatedReward: defaultViewModel.estimatedReward)
        bind(assetViewModel: defaultViewModel.assetBalance)

        leasingPeriodView.valueTop.text = defaultViewModel.leasingPeriod
        leasingPeriodView.valueBottom.text = defaultViewModel.leasingCompletionDate

        raisedView.valueTop.text = defaultViewModel.raisedProgress
        raisedView.valueBottom.text = defaultViewModel.raisedPercentage

        timeLeftVew.valueLabel.text = defaultViewModel.remainedTime
    }

    func bind(to acalaViewModel: AcalaCrowdloanContributionSetupViewModel) {
        bind(feeViewModel: acalaViewModel.fee)
        bind(bonus: acalaViewModel.bonus)
        bind(estimatedReward: acalaViewModel.estimatedReward)
        bind(assetViewModel: acalaViewModel.assetBalance)

        leasingPeriodView.valueTop.text = acalaViewModel.leasingPeriod
        leasingPeriodView.valueBottom.text = acalaViewModel.leasingCompletionDate

        raisedView.valueTop.text = acalaViewModel.raisedProgress
        raisedView.valueBottom.text = acalaViewModel.raisedPercentage

        timeLeftVew.valueLabel.text = acalaViewModel.remainedTime
    }

    private func applyLocalization() {
        contributionTitleLabel.text = R.string.localizable.crowdloanContributeTitle(
            preferredLanguages: locale.rLanguages
        )

        networkFeeView.locale = locale
        leasingPeriodView.titleLabel.text = R.string.localizable.crowdloanLeasingPeriod(
            preferredLanguages: locale.rLanguages
        )

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        crowdloanInfoTitleLabel.text = R.string.localizable.crowdloanInfo(preferredLanguages: locale.rLanguages)

        raisedView.titleLabel.text = R.string.localizable.crowdloanRaised(preferredLanguages: locale.rLanguages)
        timeLeftVew.titleLabel.text = R.string.localizable.commonTimeLeft(preferredLanguages: locale.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        estimatedRewardView.titleLabel.text = R.string.localizable.crowdloanReward(
            preferredLanguages: locale.rLanguages
        )

        bonusView.rowContentView.titleLabel.text = R.string.localizable.commonBonus(
            preferredLanguages: locale.rLanguages
        )

        ethereumAddressForRewardView.ethereumAddressView.animatedInputField.title = R.string.localizable
            .moonbeanEthereumAddress(preferredLanguages: locale.rLanguages)

        ethereumAddressForRewardView.ethereumHintView.titleLabel.text = R.string.localizable
            .moonbeamAddressHint(preferredLanguages: locale.rLanguages)
    }
}
