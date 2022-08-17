import UIKit

final class StakingPoolJoinConfigViewLayout: UIView {
    private enum LayoutConstants {
        static let accountViewHeight: CGFloat = 64.0
        static let amountViewHeight: CGFloat = 92.0
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        bar.backButton.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.08)
        bar.backButton.layer.cornerRadius = bar.backButton.frame.size.height / 2
        bar.backgroundColor = R.color.colorAlmostBlack()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let accountView: DetailsTriangularedView = UIFactory.default.createAccountView(for: .options, filled: true)
    let amountView: AmountInputView = UIFactory.default.createAmountInputView(filled: true)

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorAlmostBlack()
        setupLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(accountViewModel: AccountViewModel) {
        let icon = accountViewModel.icon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: UIConstants.normalAddressIconSize,
            contentScale: UIScreen.main.scale
        )

        accountView.iconImage = icon ?? R.image.iconBirdGreen()
        accountView.subtitle = accountViewModel.name
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

    private func applyLocalization() {
        accountView.title = R.string.localizable.poolStakingJoinAccountTitle(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.poolStakingJoinTitle(
            preferredLanguages: locale.rLanguages
        ))
        amountView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        continueButton.imageWithTitleView?.title = R.string.localizable.poolStakingJoinButtonTitle(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(continueButton)

        contentView.stackView.addArrangedSubview(accountView)
        contentView.stackView.addArrangedSubview(amountView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(continueButton.snp.bottom).offset(UIConstants.bigOffset)
        }

        continueButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        accountView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        amountView.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.amountViewHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
    }
}
