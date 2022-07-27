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

    let tipAndFeeView = UIFactory.default.createNetworkFeeFooterView()

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
        tipAndFeeView.locale = locale

        amountView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        tipAndFeeView.actionButton.imageWithTitleView?.title = R.string.localizable
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

        let viewOffset = -2.0 * UIConstants.horizontalInset

        contentView.stackView.addArrangedSubview(senderView) {
            $0.width.equalTo(self).offset(viewOffset)
            $0.height.equalTo(UIConstants.triangularedViewHeight)
        }

        contentView.stackView.setCustomSpacing(16.0, after: senderView)

        contentView.stackView.addArrangedSubview(receiverView) {
            $0.width.equalTo(self).offset(viewOffset)
            $0.height.equalTo(UIConstants.triangularedViewHeight)
        }

        contentView.stackView.setCustomSpacing(16.0, after: receiverView)

        contentView.stackView.addArrangedSubview(amountView) {
            $0.width.equalTo(self).offset(viewOffset)
            $0.height.equalTo(UIConstants.amountViewHeight)
        }

        addSubview(tipAndFeeView) { $0.leading.bottom.trailing.equalToSuperview() }
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

    func bind(tipViewModel: BalanceViewModelProtocol?, isRequired: Bool) {
        tipAndFeeView.tipView.bind(viewModel: tipViewModel)
        tipAndFeeView.tipView.isHidden = !isRequired
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        tipAndFeeView.bindBalance(viewModel: feeViewModel)
    }
}
