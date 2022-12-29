import UIKit

final class StakingRedeemConfirmationLayout: UIView {
    enum Constants {
        static let hintsSpacing: CGFloat = 9
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
        view.stackView.alignment = .fill
        return view
    }()

    let stakeAmountView = StakeAmountView()

    let networkFeeFooterView = UIFactory().createCleanNetworkFeeFooterView()
    let infoBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let collatorView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let accountView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let amountView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let feeView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let infoStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

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

        backgroundColor = R.color.colorBlack19()!

        setupLayout()

        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
    }

    func bind(confirmationViewModel: StakingRedeemConfirmationViewModel) {
        if let senderName = confirmationViewModel.senderName {
            accountView.valueTop.lineBreakMode = .byTruncatingTail
            accountView.valueTop.text = senderName
        }

        accountView.valueBottom.text = confirmationViewModel.senderAddress

        if let collatorName = confirmationViewModel.collatorName {
            collatorView.isHidden = false
            collatorView.valueTop.text = collatorName
        } else {
            collatorView.isHidden = true
        }

        if let stakedViewModel = confirmationViewModel.stakeAmountViewModel?.value(for: locale) {
            stakeAmountView.bind(viewModel: stakedViewModel)
        }

        amountView.valueTop.text = confirmationViewModel.amountString.value(for: locale)

        setNeedsLayout()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
        setNeedsLayout()
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.valueBottom.text = assetViewModel.price
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
                contentView.stackView.insertArranged(view: view, after: hintViews[index - 1])
            } else {
                contentView.stackView.insertArranged(view: view, after: infoBackground)
            }

            view.snp.makeConstraints { make in
                make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            }

            contentView.stackView.setCustomSpacing(Constants.hintsSpacing, after: view)
        }
    }

    private func applyLocalization() {
        accountView.titleLabel.text = R.string.localizable.commonAccount(preferredLanguages: locale.rLanguages)
        collatorView.titleLabel.text = R.string.localizable.parachainStakingCollator(preferredLanguages: locale.rLanguages)

        amountView.titleLabel.text = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        networkFeeFooterView.locale = locale

        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(preferredLanguages: locale.rLanguages)

        navigationBar.setTitle(R.string.localizable.commonConfirmTitle(preferredLanguages: locale.rLanguages))
        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
        }

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(stakeAmountView)
        contentView.stackView.addArrangedSubview(infoBackground)

        infoBackground.addSubview(infoStackView)
        infoStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        infoStackView.addArrangedSubview(collatorView)
        infoStackView.addArrangedSubview(accountView)
        infoStackView.addArrangedSubview(amountView)
        infoStackView.addArrangedSubview(feeView)

        accountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        amountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        feeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        addSubview(networkFeeFooterView)

        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(contentView.snp.bottom)
        }
    }
}
