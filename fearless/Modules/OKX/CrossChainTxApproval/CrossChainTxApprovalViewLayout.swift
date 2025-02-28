import UIKit

final class CrossChainFundsPermissionViewLayout: UIView {
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
    let senderView: TitleMultiValueView = createMultiView()
    let receiverView: TitleMultiValueView = createMultiView()
    let amountView: TitleMultiValueView = createMultiView()
    let feeView: TitleMultiValueView = createMultiView()

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()
    
    let warningView = WarningView()
    let errorView: ErrorView = {
        let view = ErrorView()
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

    func bind(viewModel: CrossChainFundsPermissionViewModel) {
        amountLabel.attributedText = viewModel.amountLabelText
        senderView.bind(viewModel: viewModel.fromViewModel)
        receiverView.bind(viewModel: viewModel.requestFromViewModel)
        amountView.bindBalance(viewModel: viewModel.amountViewModel)
        symbolView.bind(viewModel: viewModel.symbolViewModel)
        warningView.textLabel.text = viewModel.warningText
        confirmButton.imageWithTitleView?.title = viewModel.confirmButtonTitle

    }
    
    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bindBalance(viewModel: feeViewModel)
    }
    
    func bind(errorViewModel: ErrorViewModel?) {
        errorView.isHidden = errorViewModel == nil

        if let errorVM = errorViewModel {
            errorView.bindError(viewModel: errorVM)
        }
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
        senderView.borderView.isHidden = true
        receiverView.borderView.isHidden = true
        amountView.borderView.isHidden = true
        feeView.borderView.isHidden = true
    }

    private func applyLocalization() {
        senderView.titleLabel.text = R.string.localizable.transactionDetailsFrom(
            preferredLanguages: locale.rLanguages
        )
        receiverView.titleLabel.text = R.string.localizable.crossChainFundsPermissionRequestFromTitle(
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
        warningView.titleLabel.text = R.string.localizable.commonImportant(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(confirmButton)

        contentView.stackView.addArrangedSubview(symbolView)
        contentView.stackView.addArrangedSubview(amountLabel)
        contentView.stackView.addArrangedSubview(infoBackground)
        contentView.stackView.addArrangedSubview(warningView)
        contentView.stackView.addArrangedSubview(errorView)

        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(senderView)
        infoViewsStackView.addArrangedSubview(receiverView)
        infoViewsStackView.addArrangedSubview(amountView)
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
        
        contentView.scrollView.contentInset = .init(top: 0, left: 0, bottom: UIConstants.bigOffset * 2 + UIConstants.actionHeight, right: 0)

        infoBackground.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
        
        warningView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
        
        errorView.snp.makeConstraints { make in
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
    }
    
    private static func createMultiView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.equalsLabelsWidth = true
        return view
    }
}
