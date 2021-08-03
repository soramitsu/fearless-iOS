import UIKit

final class StakingRewardDestConfirmViewLayout: UIView {
    let stackView: UIStackView = {
        let view = UIStackView()
        view.isLayoutMarginsRelativeArrangement = true
        view.layoutMargins = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.axis = .vertical
        view.alignment = .center
        view.distribution = .fill
        return view
    }()

    let senderAccountView: DetailsTriangularedView = UIFactory.default.createAccountView()
    let typeView: TitleValueView = {
        let view = UIFactory.default.createTitleValueView()
        view.borderView.borderType = .none
        return view
    }()

    private(set) var payoutAccountView: DetailsTriangularedView?

    private(set) var separatorView = UIFactory.default.createSeparatorView()

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

    private func insertPayoutViewIfNeeded() {
        guard payoutAccountView == nil else {
            return
        }

        let payoutView = UIFactory.default.createAccountView(for: .options, filled: true)
        payoutView.title = R.string.localizable
            .stakingRewardPayoutAccount(preferredLanguages: locale.rLanguages)

        if let insertionIndex = stackView.arrangedSubviews
            .firstIndex(where: { $0 == typeView }) {
            stackView.insertArrangedSubview(payoutView, at: insertionIndex + 1)

            payoutView.snp.makeConstraints { make in
                make.width.equalTo(stackView)
                make.height.equalTo(52)
            }

            stackView.setCustomSpacing(16.0, after: payoutView)

            payoutAccountView = payoutView
        }
    }

    private func removePayoutViewIfNeeded() {
        if let payoutAccountView = payoutAccountView {
            stackView.removeArrangedSubview(payoutAccountView)
            payoutAccountView.removeFromSuperview()

            self.payoutAccountView = nil
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(confirmationViewModel: StakingRewardDestConfirmViewModel) {
        senderAccountView.subtitle = confirmationViewModel.senderName

        let iconSize = 2.0 * senderAccountView.iconRadius
        senderAccountView.iconImage = confirmationViewModel.senderIcon.imageWithFillColor(
            R.color.colorWhite()!,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )

        switch confirmationViewModel.rewardDestination {
        case .restake:
            typeView.valueLabel.text = R.string.localizable
                .stakingRestakeTitle(preferredLanguages: locale.rLanguages)

        case let .payout(icon, title):
            typeView.valueLabel.text = R.string.localizable
                .stakingPayoutTitle(preferredLanguages: locale.rLanguages)
            insertPayoutViewIfNeeded()

            payoutAccountView?.iconImage = icon.imageWithFillColor(
                R.color.colorWhite()!,
                size: UIConstants.smallAddressIconSize,
                contentScale: UIScreen.main.scale
            )

            payoutAccountView?.subtitle = title
        }

        setNeedsLayout()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeConfirmView.networkFeeView.bind(viewModel: feeViewModel)
        setNeedsLayout()
    }

    private func applyLocalization() {
        senderAccountView.title = R.string.localizable.commonAccount(preferredLanguages: locale.rLanguages)

        typeView.titleLabel.text = R.string.localizable
            .stakingRewardsDestinationTitle(preferredLanguages: locale.rLanguages)

        payoutAccountView?.title = R.string.localizable
            .stakingRewardPayoutAccount(preferredLanguages: locale.rLanguages)

        networkFeeConfirmView.locale = locale

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        stackView.addArrangedSubview(senderAccountView)
        senderAccountView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(52)
        }

        stackView.setCustomSpacing(16.0, after: senderAccountView)

        stackView.addArrangedSubview(typeView)
        typeView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(48.0)
        }

        stackView.addArrangedSubview(separatorView)
        separatorView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(UIConstants.separatorHeight)
        }

        addSubview(networkFeeConfirmView)

        networkFeeConfirmView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
