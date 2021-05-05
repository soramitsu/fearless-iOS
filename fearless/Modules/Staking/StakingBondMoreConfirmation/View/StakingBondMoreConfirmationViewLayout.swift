import UIKit

final class StakingBMConfirmationViewLayout: UIView {
    let stackView: UIStackView = {
        let view = UIStackView()
        view.isLayoutMarginsRelativeArrangement = true
        view.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.axis = .vertical
        view.alignment = .center
        view.distribution = .fill
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView()

    let amountView: AmountInputView = {
        let view = UIFactory().createAmountInputView(filled: true)
        view.isUserInteractionEnabled = false
        return view
    }()

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

        let iconSize = 2.0 * accountView.iconRadius
        accountView.iconImage = confirmationViewModel.senderIcon.imageWithFillColor(
            R.color.colorWhite()!,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )

        amountView.fieldText = confirmationViewModel.amount.value(for: locale)

        setNeedsLayout()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeConfirmView.networkFeeView.bind(viewModel: feeViewModel)
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

        amountView.assetIcon = assetViewModel.icon

        amountView.symbol = assetViewModel.symbol.uppercased()

        setNeedsLayout()
    }

    private func applyLocalization() {
        accountView.title = R.string.localizable.commonAccount(preferredLanguages: locale.rLanguages)

        amountView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        networkFeeConfirmView.locale = locale

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(52)
        }

        stackView.setCustomSpacing(16.0, after: accountView)
        stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(72.0)
        }

        addSubview(networkFeeConfirmView)

        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
