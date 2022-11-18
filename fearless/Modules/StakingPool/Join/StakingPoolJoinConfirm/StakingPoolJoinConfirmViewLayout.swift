import UIKit

final class StakingPoolJoinConfirmViewLayout: UIView {
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

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorGray()
        label.numberOfLines = 2
        label.textAlignment = .center
        return label
    }()

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

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconPoolStaking()
        return imageView
    }()

    let infoViewsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    let accountView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let selectedPoolView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let feeView: NetworkFeeView = {
        let view = NetworkFeeView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.tokenLabel.font = .h5Title
        view.tokenLabel.textColor = R.color.colorWhite()
        view.fiatLabel?.font = .p1Paragraph
        view.fiatLabel?.textColor = R.color.colorStrokeGray()
        return view
    }()

    let continueButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let hintView: IconDetailsView = {
        let view = IconDetailsView()
        view.iconWidth = UIConstants.iconSize
        view.imageView.contentMode = .top
        view.imageView.image = R.image.iconWarning()
        view.isHidden = true
        return view
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
        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
    }

    func bind(confirmViewModel: StakingPoolJoinConfirmViewModel) {
        amountLabel.attributedText = confirmViewModel.amountAttributedString
        accountView.valueTop.text = confirmViewModel.accountNameString
        accountView.valueBottom.text = confirmViewModel.accountAddressString
        selectedPoolView.valueTop.text = confirmViewModel.selectedPoolName
        hintView.isHidden = !confirmViewModel.poolHasNoValidators
    }

    private func configure() {
        accountView.valueBottom.lineBreakMode = .byTruncatingMiddle
        accountView.valueBottom.textAlignment = .right
        accountView.valueTop.textAlignment = .right
        selectedPoolView.valueBottom.textAlignment = .right
        selectedPoolView.valueTop.textAlignment = .right
        accountView.borderView.isHidden = true
        selectedPoolView.borderView.isHidden = true
        feeView.borderType = .none
    }

    private func applyLocalization() {
        accountView.titleLabel.text = R.string.localizable.transactionDetailsFrom(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        ))
        selectedPoolView.titleLabel.text = R.string.localizable.poolStakingSelectedPool(
            preferredLanguages: locale.rLanguages
        )
        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )
        continueButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        )
        hintView.detailsLabel.text = R.string.localizable.poolJoinNoValidatorsMessage(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(hintView)
        addSubview(continueButton)

        contentView.stackView.addArrangedSubview(iconImageView)
        contentView.stackView.addArrangedSubview(amountLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(accountView)
        infoViewsStackView.addArrangedSubview(selectedPoolView)
        infoViewsStackView.addArrangedSubview(feeView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(hintView.snp.bottom).offset(UIConstants.bigOffset)
        }

        hintView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(continueButton.snp.top).inset(-UIConstants.bigOffset)
            make.height.equalTo(UIConstants.cellHeight)
        }

        continueButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        infoBackground.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoViewsStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview()
        }

        accountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        selectedPoolView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        feeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        accountView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(accountView.titleLabel.snp.width)
        }
        accountView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(accountView.titleLabel.snp.width)
        }

        selectedPoolView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(accountView.titleLabel.snp.width)
        }
        selectedPoolView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(accountView.titleLabel.snp.width)
        }
    }
}
