import UIKit

final class StakingRedeemLayout: UIView {
    enum Constants {
        static let hintsSpacing: CGFloat = 9
    }

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

    let collatorView: DetailsTriangularedView = {
        let view = UIFactory.default.createAccountView(for: .options, filled: true)
        view.iconImage = nil
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()

    let amountView: AmountInputViewV2 = {
        let view = AmountInputViewV2()
        view.isUserInteractionEnabled = false
        return view
    }()

    let networkFeeFooterView: NetworkFeeFooterView = UIFactory().createNetworkFeeFooterView()

    private(set) var hintViews: [UIView] = []

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

    func bind(confirmationViewModel: StakingRedeemViewModel) {
        if let collatorName = confirmationViewModel.collatorName {
            collatorView.isHidden = false
            collatorView.subtitle = collatorName
        } else {
            collatorView.isHidden = true
        }

        let iconSize = 2.0 * accountView.iconRadius
        collatorView.iconImage = confirmationViewModel.collatorIcon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )
        if let senderName = confirmationViewModel.senderName {
            accountView.subtitleLabel?.lineBreakMode = .byTruncatingTail
            accountView.subtitle = senderName
        } else {
            accountView.subtitleLabel?.lineBreakMode = .byTruncatingMiddle
            accountView.subtitle = confirmationViewModel.senderAddress
        }

        accountView.iconImage = confirmationViewModel.senderIcon?.imageWithFillColor(
            R.color.colorWhite()!,
            size: CGSize(width: iconSize, height: iconSize),
            contentScale: UIScreen.main.scale
        )

        amountView.inputFieldText = confirmationViewModel.amount.value(for: locale)

        setNeedsLayout()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeFooterView.bindBalance(viewModel: feeViewModel)
        setNeedsLayout()
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.bind(viewModel: assetViewModel)

        setNeedsLayout()
    }

    func bind(hintViewModels: [TitleIconViewModel]) {
        hintViews.forEach { $0.removeFromSuperview() }

        hintViews = hintViewModels.map { hint in
            let view = IconDetailsView()
            view.iconWidth = UIConstants.iconSize
            view.detailsLabel.text = hint.title
            view.imageView.image = hint.icon
            return view
        }

        for (index, view) in hintViews.enumerated() {
            if index > 0 {
                stackView.insertArranged(view: view, after: hintViews[index - 1])
            } else {
                stackView.insertArranged(view: view, after: amountView)
            }

            view.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            }

            stackView.setCustomSpacing(Constants.hintsSpacing, after: view)
        }
    }

    private func applyLocalization() {
        accountView.title = R.string.localizable.commonAccount(preferredLanguages: locale.rLanguages)
        collatorView.title = R.string.localizable.parachainStakingCollator(preferredLanguages: locale.rLanguages)

        amountView.locale = locale

        networkFeeFooterView.locale = locale

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        stackView.addArrangedSubview(collatorView)
        collatorView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(UIConstants.actionHeight)
        }

        stackView.setCustomSpacing(UIConstants.bigOffset, after: collatorView)
        stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(UIConstants.actionHeight)
        }

        stackView.setCustomSpacing(UIConstants.bigOffset, after: accountView)
        stackView.addArrangedSubview(amountView)
        amountView.snp.makeConstraints { make in
            make.width.equalTo(stackView)
            make.height.equalTo(UIConstants.amountViewV2Height)
        }
        stackView.setCustomSpacing(UIConstants.bigOffset, after: amountView)

        addSubview(networkFeeFooterView)

        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
        }
    }
}
