import UIKit

final class StakingBondMoreViewLayout: UIView {
    private enum Constants {
        static let hintIconWidth: CGFloat = 24.0
    }

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

    let amountInputView = AmountInputViewV2()

    let hintView: IconDetailsView = {
        let view = IconDetailsView()
        view.iconWidth = Constants.hintIconWidth
        view.imageView.contentMode = .top
        view.imageView.image = R.image.iconGeneralReward()
        view.isHidden = true
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

        backgroundColor = R.color.colorBlack()
        applyLocalization()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(feeViewModel: NetworkFeeFooterViewModelProtocol) {
        let balanceViewModel: BalanceViewModelProtocol = feeViewModel.balanceViewModel.value(for: locale)
        networkFeeFooterView.actionTitle = feeViewModel.actionTitle
        networkFeeFooterView.bindBalance(viewModel: balanceViewModel)
        setNeedsLayout()
    }

    private func applyLocalization() {
        networkFeeFooterView.locale = locale
        amountInputView.locale = locale
        hintView.detailsLabel.text = R.string.localizable.stakingHintRewardBondMore(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(contentView)

        contentView.stackView.addArrangedSubview(collatorView)
        contentView.stackView.addArrangedSubview(accountView)
        contentView.stackView.addArrangedSubview(amountInputView)
        contentView.stackView.addArrangedSubview(hintView)

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
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalTo(networkFeeFooterView.snp.top).inset(UIConstants.bigOffset)
        }

        accountView.isHidden = true
        collatorView.isHidden = true
    }
}
