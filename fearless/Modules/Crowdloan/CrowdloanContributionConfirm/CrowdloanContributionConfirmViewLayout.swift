import UIKit

final class CrowdloanContributionConfirmViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView()

    let amountInputView: AmountInputView = {
        let view = UIFactory().createAmountInputView(filled: true)
        view.isUserInteractionEnabled = false
        return view
    }()

    private(set) var estimatedRewardView: TitleValueView?

    private(set) var bonusView: TitleValueView?

    let leasingPeriodView = TitleMultiValueView()

    let networkFeeConfirmView: NetworkFeeConfirmView = UIFactory().createNetworkFeeConfirmView()

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

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
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
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeConfirmView.networkFeeView.bind(viewModel: feeViewModel)
    }

    func bind(estimatedReward: String?) {
        if let estimatedReward = estimatedReward {
            createEstimatedRewardViewIfNeeded()
            estimatedRewardView?.valueLabel.text = estimatedReward
        } else {
            removeEstimatedRewardViewIfNeeded()
        }
    }

    func bind(bonus: String?) {
        if let bonus = bonus {
            createBonusViewIfNeeded()
            bonusView?.valueLabel.text = bonus
        } else {
            removeBonusViewIfNeeded()
        }
    }

    func bind(confirmationViewModel: CrowdloanContributeConfirmViewModel) {
        let icon = confirmationViewModel.senderIcon.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        accountView.iconImage = icon
        accountView.subtitle = confirmationViewModel.senderName

        amountInputView.fieldText = confirmationViewModel.inputAmount

        leasingPeriodView.valueTop.text = confirmationViewModel.leasingPeriod
        leasingPeriodView.valueBottom.text = confirmationViewModel.leasingCompletionDate
    }

    private func applyLocalization() {
        accountView.title = R.string.localizable.commonAccount(preferredLanguages: locale.rLanguages)

        networkFeeConfirmView.locale = locale

        leasingPeriodView.titleLabel.text = R.string.localizable.crowdloanLeasingPeriod(
            preferredLanguages: locale.rLanguages
        )

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        estimatedRewardView?.titleLabel.text = R.string.localizable.crowdloanReward(
            preferredLanguages: locale.rLanguages
        )

        bonusView?.titleLabel.text = R.string.localizable.commonBonus(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52)
        }

        contentView.stackView.setCustomSpacing(16.0, after: accountView)

        contentView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(72.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: amountInputView)

        contentView.stackView.addArrangedSubview(leasingPeriodView)
        leasingPeriodView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        addSubview(networkFeeConfirmView)

        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }

    private func createEstimatedRewardViewIfNeeded() {
        guard estimatedRewardView == nil else {
            return
        }

        guard let leasingPeriodIndex = contentView.stackView.arrangedSubviews.firstIndex(
            of: leasingPeriodView
        ) else {
            return
        }

        let view = TitleValueView()
        view.titleLabel.text = R.string.localizable.crowdloanReward(preferredLanguages: locale.rLanguages)

        contentView.stackView.insertArrangedSubview(view, at: leasingPeriodIndex + 1)
        view.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        estimatedRewardView = view
    }

    private func removeEstimatedRewardViewIfNeeded() {
        guard let estimatedRewardView = estimatedRewardView else {
            return
        }

        contentView.stackView.removeArrangedSubview(estimatedRewardView)
        estimatedRewardView.removeFromSuperview()

        self.estimatedRewardView = nil
    }

    private func createBonusViewIfNeeded() {
        guard bonusView == nil else {
            return
        }

        let maybeLastViewIndex: Int? = {
            if let estimatedRewardView = estimatedRewardView {
                return contentView.stackView.arrangedSubviews.firstIndex(
                    of: estimatedRewardView
                )
            }

            return contentView.stackView.arrangedSubviews.firstIndex(of: leasingPeriodView)
        }()

        guard
            let lastIndex = maybeLastViewIndex else {
            return
        }

        let view = TitleValueView()
        view.titleLabel.text = R.string.localizable.commonBonus(preferredLanguages: locale.rLanguages)
        view.valueLabel.textColor = R.color.colorAccent()

        contentView.stackView.insertArrangedSubview(view, at: lastIndex + 1)
        view.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        bonusView = view
    }

    private func removeBonusViewIfNeeded() {
        guard let bonusView = bonusView else {
            return
        }

        contentView.stackView.removeArrangedSubview(bonusView)
        bonusView.removeFromSuperview()

        self.bonusView = nil
    }
}
