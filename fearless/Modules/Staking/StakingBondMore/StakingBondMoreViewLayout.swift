import UIKit

final class StakingBondMoreViewLayout: UIView {
    private enum Constants {
        static let hintIconWidth: CGFloat = 24.0
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
        view.stackView.layoutMargins = UIEdgeInsets(top: UIConstants.hugeOffset, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let accountView: DetailsTriangularedView = {
        let view = UIFactory.default.createAccountView(for: .options, filled: true)
        view.actionImage = nil
        return view
    }()

    let collatorView: DetailsTriangularedView = {
        let view = UIFactory.default.createAccountView(for: .options, filled: true)
        view.actionImage = nil
        return view
    }()

    let amountInputView: AmountInputView = {
        let view = UIFactory().createAmountInputView(filled: true)
        return view
    }()

    let hintView: IconDetailsView = {
        let view = IconDetailsView()
        view.iconWidth = Constants.hintIconWidth
        view.imageView.contentMode = .top
        view.imageView.image = R.image.iconGeneralReward()
        view.isHidden = true
        return view
    }()

    let networkFeeFooterView = UIFactory().createCleanNetworkFeeFooterView()

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
        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(feeViewModel: NetworkFeeFooterViewModelProtocol?) {
        networkFeeFooterView.actionTitle = feeViewModel?.actionTitle
        networkFeeFooterView.bindBalance(viewModel: feeViewModel?.balanceViewModel.value(for: locale))
        setNeedsLayout()
    }

    private func applyLocalization() {
        networkFeeFooterView.locale = locale
        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)
        hintView.detailsLabel.text = R.string.localizable.stakingHintRewardBondMore(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable
            .stakingBondMore_v190(preferredLanguages: locale.rLanguages))
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.stackView.addArrangedSubview(collatorView)
        contentView.stackView.addArrangedSubview(accountView)
        contentView.stackView.addArrangedSubview(amountInputView)
        contentView.stackView.addArrangedSubview(hintView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        collatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        accountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        amountInputView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.amountViewHeight)
        }

        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: amountInputView)
        hintView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.height.equalTo(UIConstants.cellHeight)
        }

        addSubview(networkFeeFooterView)
        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(networkFeeFooterView.snp.top).inset(UIConstants.bigOffset)
        }

        accountView.isHidden = true
        collatorView.isHidden = true
    }
}
