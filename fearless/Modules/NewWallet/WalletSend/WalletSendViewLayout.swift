import UIKit

final class WalletSendViewLayout: UIView {
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

    let addressView = UIFactory.default.createAccountView(for: .options, filled: false)
    let amountView = UIFactory.default.createAmountInputView(filled: false)
    let feeView = UIFactory.default.createNetworkFeeView()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

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

    func setupLayout() {
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

        contentView.stackView.addArrangedSubview(addressView)
        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: addressView)
        contentView.stackView.addArrangedSubview(amountView)
        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: amountView)
        contentView.stackView.addArrangedSubview(feeView)

        addressView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.triangularedViewHeight)
        }

        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.amountViewHeight)
        }

        feeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.cellHeight)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.scrollBottomOffset = 2 * UIConstants.horizontalInset + UIConstants.actionHeight
    }

    func bind(accountViewModel: AccountViewModel) {
        let icon = accountViewModel.icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.smallAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        addressView.title = accountViewModel.title
        addressView.iconImage = icon ?? R.image.iconBirdGreen()
        addressView.subtitle = accountViewModel.name
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
        feeView.bind(viewModel: feeViewModel)
    }

    private func applyLocalization() {
        feeView.locale = locale

        amountView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)
    }
}
