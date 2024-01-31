import UIKit

final class NftSendConfirmViewLayout: UIView {
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

    let imageView = UIImageView()
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorGray()
        return label
    }()

    let infoViewsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
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
        button.isHidden = true
        return button
    }()

    let collectionView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.numberOfLines = 0
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

        navigationBar.backButton.rounded()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure() {
        senderView.valueTop.lineBreakMode = .byTruncatingMiddle
        senderView.valueTop.textAlignment = .right
        receiverView.valueTop.lineBreakMode = .byTruncatingMiddle
        receiverView.valueTop.textAlignment = .right
        collectionView.valueBottom.textAlignment = .right
        collectionView.valueTop.textAlignment = .right
        feeView.valueBottom.textAlignment = .right
        feeView.valueTop.textAlignment = .right
        senderView.borderView.isHidden = true
        receiverView.borderView.isHidden = true
        feeView.borderView.isHidden = true
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
        collectionView.titleLabel.text = R.string.localizable.nftCollectionTitle(
            preferredLanguages: locale.rLanguages
        )
        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        )
        titleLabel.text = R.string.localizable.sendConfirmAmountTitle("", preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(confirmButton)

        contentView.stackView.addArrangedSubview(imageView)
        contentView.stackView.addArrangedSubview(titleLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        receiverStack.addArrangedSubview(receiverView)
        receiverStack.addArrangedSubview(receiverWarningButton)

        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(senderView)
        infoViewsStackView.addArrangedSubview(receiverStack)
        infoViewsStackView.addArrangedSubview(collectionView)
        infoViewsStackView.addArrangedSubview(feeView)

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

        collectionView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        feeView.snp.makeConstraints { make in
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

        collectionView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(receiverView.titleLabel.snp.width)
        }
        collectionView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(receiverView.titleLabel.snp.width)
        }

        feeView.valueBottom.snp.makeConstraints { make in
            make.width.equalTo(feeView.titleLabel.snp.width)
        }
        feeView.valueTop.snp.makeConstraints { make in
            make.width.equalTo(feeView.titleLabel.snp.width)
        }
    }

    func bind(nftViewModel: NftSendConfirmViewModel) {
        collectionView.valueTop.text = nftViewModel.collectionName
        nftViewModel.nftImage?.loadImage(on: imageView, targetSize: CGSize(width: 80, height: 80), animated: true)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.valueTop.text = feeViewModel?.amount
        feeView.valueBottom.text = feeViewModel?.price
    }

    func bind(receiverViewModel: AccountViewModel?) {
        receiverView.valueTop.text = receiverViewModel?.name
    }

    func bind(senderViewModel: AccountViewModel?) {
        senderView.valueTop.text = senderViewModel?.name
    }
}
