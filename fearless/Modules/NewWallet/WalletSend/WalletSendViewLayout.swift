import UIKit

final class WalletSendViewLayout: UIView {
    enum LayoutConstants {
        static let verticalOffset: CGFloat = 25
    }

    let navigationBar: BaseNavigationBar = {
        let view = BaseNavigationBar()
        view.backgroundColor = R.color.colorBlack19()
        return view
    }()

    let navigationTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textColor = .white
        return label
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let amountView = NewAmountInputView()
    let scamWarningView = ScamWarningExpandableView()

    let feeView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.borderView.isHidden = true
        return view
    }()

    let tipView: NetworkFeeView = {
        let view = UIFactory.default.createNetworkFeeView()
        view.borderView.isHidden = true
        return view
    }()

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
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

        backgroundColor = R.color.colorBlack19()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.bind(viewModel: assetViewModel)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
    }

    func bind(tipViewModel: BalanceViewModelProtocol?, isRequired: Bool) {
        tipView.bind(viewModel: tipViewModel)
        tipView.isHidden = !isRequired
    }

    func bind(scamInfo: ScamInfo?) {
        guard let scamInfo = scamInfo else {
            scamWarningView.isHidden = true
            return
        }
        scamWarningView.isHidden = false

        scamWarningView.bind(scamInfo: scamInfo, assetName: amountView.symbol ?? "")
    }
}

private extension WalletSendViewLayout {
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

        let viewOffset = -2.0 * UIConstants.horizontalInset
        contentView.stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
        }

        contentView.stackView.setCustomSpacing(UIConstants.verticalInset, after: amountView)
        contentView.stackView.addArrangedSubview(scamWarningView)
        scamWarningView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(viewOffset)
        }

        addSubview(actionButton) { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalToSuperview().inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(feeView) { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.cellHeight)
            make.bottom.equalTo(actionButton.snp.top).offset(-LayoutConstants.verticalOffset)
        }

        addSubview(tipView) { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.cellHeight)
            make.bottom.equalTo(feeView.snp.top).offset(LayoutConstants.verticalOffset)
        }
    }

    func applyLocalization() {
        feeView.locale = locale
        amountView.locale = locale

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonPreview(preferredLanguages: locale.rLanguages)

        tipView.titleLabel.text = R.string.localizable.walletSendTipTitle(preferredLanguages: locale.rLanguages)

        navigationTitleLabel.text = R.string.localizable
            .chooseRecipientNextButtonTitle(preferredLanguages: locale.rLanguages)
    }
}
