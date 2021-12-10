import UIKit

final class WalletSendConfirmViewLayout: UIView {
    let navigationBar = BaseNavigationBar()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h3Title
        label.textColor = .white
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let senderView = UIFactory.default.createAccountView(for: .options, filled: false)
    let receiverView = UIFactory.default.createAccountView(for: .options, filled: false)
    let amountView: AmountInputView = {
        let view = UIFactory.default.createAmountInputView(filled: true)
        view.isUserInteractionEnabled = false
        return view
    }()

    let feeView = UIFactory.default.createNetworkFeeConfirmView()

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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func applyLocalization() {
        feeView.locale = locale

        amountView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        feeView.actionButton.imageWithTitleView?.title = R.string.localizable
            .commonConfirm(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)

        navigationBar.setCenterViews([navigationTitleLabel])

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
        }

        contentView.stackView.addArrangedSubview(senderView)
        senderView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52)
        }

        contentView.stackView.setCustomSpacing(16.0, after: senderView)

        contentView.stackView.addArrangedSubview(receiverView)
        receiverView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(52.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: receiverView)

        contentView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(72.0)
        }

        addSubview(feeView)

        feeView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }

    func bind(senderAccountViewModel: AccountViewModel) {
        let icon = senderAccountViewModel.icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        senderView.title = senderAccountViewModel.title
        senderView.iconImage = icon
        senderView.subtitle = senderAccountViewModel.name
    }

    func bind(receiverAccountViewModel: AccountViewModel) {
        let icon = receiverAccountViewModel.icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        receiverView.title = receiverAccountViewModel.title
        receiverView.iconImage = icon
        receiverView.subtitle = receiverAccountViewModel.name
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        assetViewModel.iconViewModel?.cancel(on: amountView.iconView)
        amountView.iconView.image = nil

        amountView.priceText = assetViewModel.price

        if let balance = assetViewModel.balance {
            amountView.balanceText = R.string.localizable.commonAvailableFormat(
                balance,
                preferredLanguages: locale.rLanguages
            )
        } else {
            amountView.balanceText = nil
        }

        let symbol = assetViewModel.symbol.uppercased()
        amountView.symbol = symbol

        assetViewModel.iconViewModel?.loadAmountInputIcon(on: amountView.iconView, animated: true)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.networkFeeView.bind(viewModel: feeViewModel)
    }
}
