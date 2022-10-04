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

    let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = R.image.iconPoolStaking()
        return imageView
    }()

    let infoViewsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    let senderView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = .white
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let receiverView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = .white
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
        view.valueTop.textColor = .white
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let feeView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = .white
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let tipView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = .white
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        return view
    }()

    let confirmButton: TriangularedButton = {
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

    func bind(confirmViewModel: WalletSendConfirmViewModel) {
        amountLabel.attributedText = confirmViewModel.amountAttributedString
        senderView.valueTop.text = confirmViewModel.senderNameString
        senderView.valueBottom.text = confirmViewModel.senderAddressString
        receiverView.valueTop.text = confirmViewModel.receiverAddressString
        amountView.valueTop.text = confirmViewModel.amountString
        amountView.valueBottom.text = confirmViewModel.priceString
        feeView.valueTop.text = confirmViewModel.feeAmountString
        feeView.valueBottom.text = confirmViewModel.feePriceString
        tipView.valueTop.text = confirmViewModel.tipAmountString
        tipView.valueBottom.text = confirmViewModel.tipPriceString
        tipView.isHidden = !confirmViewModel.tipRequired
        receiverWarningButton.isHidden = !confirmViewModel.showWarning
    }

    private func configure() {
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
    }

    private func applyLocalization() {
        senderView.titleLabel.text = R.string.localizable.transactionDetailsFrom(
            preferredLanguages: locale.rLanguages
        )
        receiverView.titleLabel.text = R.string.localizable.walletSendReceiverTitle(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.commonPreview(
            preferredLanguages: locale.rLanguages
        ))
        amountView.titleLabel.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: locale.rLanguages
        )
        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )
        tipView.titleLabel.text = R.string.localizable.walletSendTipTitle(
            preferredLanguages: locale.rLanguages
        )
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(confirmButton)

        contentView.stackView.addArrangedSubview(iconImageView)
        contentView.stackView.addArrangedSubview(amountLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        receiverStack.addArrangedSubview(receiverView)
        receiverStack.addArrangedSubview(receiverWarningButton)

        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(senderView)
        infoViewsStackView.addArrangedSubview(receiverStack)
        infoViewsStackView.addArrangedSubview(amountView)
        infoViewsStackView.addArrangedSubview(feeView)
        infoViewsStackView.addArrangedSubview(tipView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(confirmButton.snp.bottom).offset(UIConstants.bigOffset)
        }

        confirmButton.snp.makeConstraints { make in
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
    }
}
