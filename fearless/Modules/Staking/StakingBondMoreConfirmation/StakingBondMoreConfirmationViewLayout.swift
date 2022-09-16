import UIKit

final class StakingBMConfirmationViewLayout: UIView {
    let stackView: UIStackView = {
        let view = UIStackView()
        view.isLayoutMarginsRelativeArrangement = true
        view.layoutMargins = UIEdgeInsets(top: UIConstants.bigOffset, left: 0.0, bottom: 0.0, right: 0.0)
        view.axis = .vertical
        view.alignment = .center
        view.distribution = .fill
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView()

    let collatorView: DetailsTriangularedView = {
        let view = UIFactory.default.createAccountView(for: .options, filled: true)
        view.subtitleLabel?.lineBreakMode = .byTruncatingTail
        view.actionImage = nil
        view.isHidden = true
        return view
    }()

    let amountView: AmountInputViewV2 = {
        let view = AmountInputViewV2()
        view.isUserInteractionEnabled = false
        return view
    }()

    let hintView: IconDetailsView = {
        let view = IconDetailsView()
        view.iconWidth = UIConstants.iconSize
        view.imageView.contentMode = .top
        view.imageView.image = R.image.iconGeneralReward()
        return view
    }()

    let networkFeeFooterView: NetworkFeeFooterView = UIFactory().createNetworkFeeFooterView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()!

        setupLayout()

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(confirmationViewModel: StakingBondMoreConfirmViewModel) {
        if let senderName = confirmationViewModel.senderName {
            accountView.subtitleLabel?.lineBreakMode = .byTruncatingTail
            accountView.subtitle = senderName
        } else {
            accountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
            accountView.subtitle = confirmationViewModel.senderAddress
        }

        if let collatorName = confirmationViewModel.collatorName {
            collatorView.subtitle = collatorName
            let iconSize = 2.0 * collatorView.iconRadius
            collatorView.iconImage = confirmationViewModel.collatorIcon?.imageWithFillColor(
                R.color.colorWhite()!,
                size: CGSize(width: iconSize, height: iconSize),
                contentScale: UIScreen.main.scale
            )
            collatorView.isHidden = false
        } else {
            collatorView.isHidden = true
        }

        let iconSize = 2.0 * accountView.iconRadius
        accountView.iconImage = confirmationViewModel.senderIcon?.imageWithFillColor(
            R.color.colorWhite() ?? .white,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )

        amountView.inputFieldText = confirmationViewModel.amount.value(for: locale)

        setNeedsLayout()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeFooterView.bindBalance(viewModel: feeViewModel)
        setNeedsLayout()
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.priceText = assetViewModel.price

        if let balance = assetViewModel.balance {
            amountView.balanceText = R.string.localizable.commonAvailableFormat(
                balance,
                preferredLanguages: locale.rLanguages
            )
        } else {
            amountView.balanceText = nil
        }

        assetViewModel.iconViewModel?.loadAmountInputIcon(on: amountView.iconView, animated: true)
        amountView.symbol = assetViewModel.symbol.uppercased()

        setNeedsLayout()
    }

    private func applyLocalization() {
        accountView.title = R.string.localizable.commonAccount(preferredLanguages: locale.rLanguages)
        collatorView.title = R.string.localizable.parachainStakingCollator(preferredLanguages: locale.rLanguages)

        amountView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        hintView.detailsLabel.text = R.string.localizable.stakingHintRewardBondMore(
            preferredLanguages: locale.rLanguages
        )

        networkFeeFooterView.locale = locale

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        stackView.addArrangedSubview(collatorView)
        collatorView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(UIConstants.actionHeight)
        }
        stackView.setCustomSpacing(UIConstants.bigOffset, after: collatorView)

        stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(UIConstants.actionHeight)
        }
        stackView.setCustomSpacing(UIConstants.bigOffset, after: accountView)

        stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(UIConstants.amountViewHeight)
        }

        stackView.setCustomSpacing(UIConstants.bigOffset, after: amountView)
        stackView.addArrangedSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
        }

        addSubview(networkFeeFooterView)

        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
