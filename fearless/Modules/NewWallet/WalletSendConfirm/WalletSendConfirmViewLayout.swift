import UIKit

final class WalletSendConfirmViewLayout: UIView {
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
        label.textColor = R.color.colorStrokeGray()
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

    let symbolView = SymbolView()

    let infoViewsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    let networkView = SendConfirmNetworkView()
    let senderView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let receiverView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let receiverStack = UIFactory.default.createHorizontalStackView(spacing: 5)
    let receiverWarningButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconWarning(), for: .normal)
        return button
    }()

    let amountView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
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
        return view
    }()

    let tipView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    /// The deposit that opens the recipient's Solana token account. The fee above includes
    /// it; this row names it so the larger fee is explained.
    let accountCreationView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.titleLabel.numberOfLines = 0
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.valueBottom.numberOfLines = 0
        view.isHidden = true
        view.accessibilityIdentifier = "send.confirm.account-creation"
        return view
    }()

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    private(set) var currentModel: WalletSendConfirmViewModel?

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
        if FWAppearance.sendPresentationRestyled { setupAdaptiveLayout() }
        if #available(iOS 17.0, *) {
            registerForTraitChanges(
                [UITraitPreferredContentSizeCategory.self, UITraitLegibilityWeight.self]
            ) { (view: WalletSendConfirmViewLayout, _: UITraitCollection) in
                view.updateTypography()
            }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if #available(iOS 17.0, *) { return }
        updateTypography()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
        if FWAppearance.sendPresentationRestyled {
            updateNavigationTitleLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(confirmButton)

        contentView.stackView.addArrangedSubview(symbolView)
        contentView.stackView.addArrangedSubview(amountLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        receiverStack.addArrangedSubview(receiverView)
        receiverStack.addArrangedSubview(receiverWarningButton)

        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(networkView)
        infoViewsStackView.addArrangedSubview(senderView)
        infoViewsStackView.addArrangedSubview(receiverStack)
        infoViewsStackView.addArrangedSubview(amountView)
        infoViewsStackView.addArrangedSubview(feeView)
        infoViewsStackView.addArrangedSubview(accountCreationView)
        infoViewsStackView.addArrangedSubview(tipView)

        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(confirmButton.snp.top).offset(-UIConstants.defaultOffset)
        }

        confirmButton.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide).offset(UIConstants.bigOffset)
            make.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).inset(UIConstants.bigOffset)
            make.height.greaterThanOrEqualTo(UIConstants.actionHeight)
        }

        infoBackground.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoViewsStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        senderView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        receiverView.snp.makeConstraints { make in
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

        tipView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        accountCreationView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.greaterThanOrEqualTo(UIConstants.cellHeight)
        }

        senderView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(senderView.titleLabel.snp.width)
        }
        senderView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(senderView.titleLabel.snp.width)
        }

        receiverView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(receiverView.titleLabel.snp.width)
        }
        receiverView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(receiverView.titleLabel.snp.width)
        }

        amountView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(amountView.titleLabel.snp.width)
        }
        amountView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(amountView.titleLabel.snp.width)
        }

        feeView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(feeView.titleLabel.snp.width)
        }
        feeView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(feeView.titleLabel.snp.width)
        }

        tipView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(tipView.titleLabel.snp.width)
        }
        tipView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(tipView.titleLabel.snp.width)
        }

        accountCreationView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(accountCreationView.titleLabel.snp.width)
        }
        accountCreationView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(accountCreationView.titleLabel.snp.width)
        }
    }
}

extension WalletSendConfirmViewLayout {
    func bind(confirmViewModel: WalletSendConfirmViewModel) {
        currentModel = confirmViewModel
        networkView.bind(
            name: confirmViewModel.networkName,
            isTestnet: confirmViewModel.networkIsTestnet,
            icon: confirmViewModel.networkIcon,
            locale: locale
        )
        amountLabel.attributedText = confirmViewModel.amountAttributedString
        if FWAppearance.sendPresentationRestyled { localizeAmount() }
        senderView.valueTop.text = confirmViewModel.senderNameString
        senderView.valueBottom.text = confirmViewModel.senderAddressString
        receiverView.valueTop.text = confirmViewModel.receiverAddressString
        amountView.valueTop.text = confirmViewModel.amountString
        amountView.valueBottom.text = confirmViewModel.priceString
        feeView.valueTop.text = confirmViewModel.feeAmountString
        feeView.valueBottom.text = confirmViewModel.feePriceString
        tipView.valueTop.text = confirmViewModel.tipAmountString
        tipView.valueBottom.text = confirmViewModel.tipPriceString
        accountCreationView.valueTop.text = confirmViewModel.accountCreationAmountString
        accountCreationView.isHidden = confirmViewModel.accountCreationAmountString.isEmpty
        applyAccountCreationNote()
        if FWAppearance.sendPresentationRestyled {
            receiverView.valueBottom.isHidden = true
            [senderView, amountView, feeView, tipView, accountCreationView].forEach {
                $0.valueBottom.isHidden = $0.valueBottom.text?.isEmpty != false
            }
        }
        tipView.isHidden = !confirmViewModel.tipRequired
        receiverWarningButton.isHidden = !confirmViewModel.showWarning
        symbolView.bind(viewModel: confirmViewModel.symbolViewModel)

        confirmViewModel.feeAmountString.isEmpty
            ? feeView.startLoadingIfNeeded()
            : feeView.stopLoadingIfNeeded()

        if FWAppearance.sendPresentationRestyled, !confirmViewModel.tipRequired {
            tipView.stopLoadingIfNeeded()
        } else {
            confirmViewModel.tipAmountString.isEmpty
                ? tipView.startLoadingIfNeeded()
                : tipView.stopLoadingIfNeeded()
        }
    }
}

private extension WalletSendConfirmViewLayout {
    func configure() {
        senderView.valueBottom.lineBreakMode = .byTruncatingMiddle
        senderView.valueBottom.textAlignment = .right
        senderView.valueTop.textAlignment = .right
        receiverView.valueTop.lineBreakMode = .byTruncatingMiddle
        receiverView.valueTop.textAlignment = .right
        amountView.valueBottom.textAlignment = .right
        amountView.valueTop.textAlignment = .right
        feeView.valueBottom.textAlignment = .right
        feeView.valueTop.textAlignment = .right
        tipView.valueBottom.textAlignment = .right
        tipView.valueTop.textAlignment = .right
        senderView.borderView.isHidden = true
        receiverView.borderView.isHidden = true
        amountView.borderView.isHidden = true
        feeView.borderView.isHidden = true
        tipView.borderView.isHidden = true
        accountCreationView.valueBottom.textAlignment = .right
        accountCreationView.valueTop.textAlignment = .right
        accountCreationView.borderView.isHidden = true
    }
}

extension WalletSendConfirmViewLayout {
    /// "Included in the network fee", with the deposit's fiat value when there is a price.
    func applyAccountCreationNote() {
        let note = R.string.localizable.solanaTransferAccount_creationIncluded(preferredLanguages: locale.rLanguages)
        let price = currentModel?.accountCreationPriceString ?? ""
        accountCreationView.valueBottom.text = price.isEmpty ? note : "\(price) · \(note)"
    }
}

/// Always visible first detail; long network names and accessibility text wrap without truncation.
final class SendConfirmNetworkView: UIView {
    let titleLabel = UILabel()
    let nameLabel = UILabel()
    let testnetLabel = UILabel()
    private let iconView = UIImageView()
    private var networkName = ""
    private var networkIsTestnet = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        let labels = UIStackView(arrangedSubviews: [titleLabel, nameLabel, testnetLabel])
        labels.axis = .vertical
        labels.spacing = 6
        let row = UIStackView(arrangedSubviews: [labels, iconView])
        row.alignment = .top
        row.spacing = 12
        addSubview(row)
        row.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        iconView.snp.makeConstraints { make in
            // UIStackView collapses a missing icon, returning its space to the network name.
            make.width.equalTo(28).priority(999)
            make.height.equalTo(28)
        }
        iconView.isHidden = true
        [titleLabel, nameLabel, testnetLabel].forEach {
            $0.numberOfLines = 0
            $0.adjustsFontForContentSizeCategory = true
            $0.textColor = R.color.colorWhite()
        }
        // These app styles already use UIFontMetrics. Scaling them again raises
        // NSInvalidArgumentException on current UIKit.
        titleLabel.font = .capsTitle
        nameLabel.font = .h5Title
        testnetLabel.font = .p2Paragraph
        titleLabel.textColor = R.color.colorStrokeGray()
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func bind(name: String, isTestnet: Bool, icon: ImageViewModelProtocol?, locale: Locale) {
        networkName = name
        networkIsTestnet = isTestnet
        refreshPresentation(locale: locale)
        iconView.image = nil
        iconView.isHidden = icon == nil
        icon?.loadImage(on: iconView, targetSize: CGSize(width: 28, height: 28), animated: false)
    }

    func refreshPresentation(locale: Locale) {
        let name = networkName
        let isTestnet = networkIsTestnet
        titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages).uppercased(with: locale)
        nameLabel.text = name
        testnetLabel.text = R.string.localizable.labelTestnet(preferredLanguages: locale.rLanguages).uppercased(with: locale) + " · " +
            R.string.localizable.sendConfirmTest_tokens_no_value(preferredLanguages: locale.rLanguages)
        testnetLabel.isHidden = !isTestnet
        if FWAppearance.sendPresentationRestyled {
            titleLabel.font = .fw(.bodyS, locale: locale, compatibleWith: traitCollection)
            nameLabel.font = .fw(.titleS, locale: locale, compatibleWith: traitCollection)
            testnetLabel.font = .fw(.bodyM, locale: locale, compatibleWith: traitCollection)
        }
        accessibilityLabel = [titleLabel.text, name, isTestnet ? testnetLabel.text : nil].compactMap { $0 }.joined(separator: ", ")
    }
}
