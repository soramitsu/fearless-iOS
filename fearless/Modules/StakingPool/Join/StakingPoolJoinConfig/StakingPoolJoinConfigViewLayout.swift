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

    let accountView: DetailsTriangularedView = {
        let view = UIFactory.default.createAccountView(for: .none, filled: true)
        view.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.strokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.highlightedStrokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.strokeWidth = 0.5
        return view
    }()

    let amountView = AmountInputViewV2()

    let feeView: NetworkFeeFooterView = {
        let view = UIFactory.default.createNetworkFeeFooterView()
        view.backgroundColor = R.color.colorBlack19()
        view.networkFeeView?.borderType = .none
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
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
        amountView.bind(viewModel: assetViewModel)
    }

    private func applyLocalization() {
        accountView.title = R.string.localizable.poolStakingJoinAccountTitle(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.poolStakingJoinTitle(
            preferredLanguages: locale.rLanguages
        ))

        feeView.actionButton.imageWithTitleView?.title = R.string.localizable.poolStakingJoinButtonTitle(
            preferredLanguages: locale.rLanguages
        )
        feeView.locale = locale
        amountView.locale = locale
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(feeView)

        contentView.stackView.addArrangedSubview(accountView)
        contentView.stackView.addArrangedSubview(amountView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(feeView.snp.bottom).offset(UIConstants.bigOffset)
        }

        feeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
        }

        accountView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.actionHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        amountView.snp.makeConstraints { make in
            make.height.equalTo(UIConstants.amountViewV2Height)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        feeView.networkFeeView?.borderType = .none
        feeView.networkFeeView?.borderView.borderType = .none
    }
}
