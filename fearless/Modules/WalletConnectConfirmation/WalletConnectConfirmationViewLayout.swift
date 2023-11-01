import UIKit

final class WalletConnectConfirmationViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.push)
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.spacing = UIConstants.defaultOffset
        view.scrollView.contentInset = UIEdgeInsets(
            top: UIConstants.bigOffset,
            left: 0,
            bottom: UIConstants.actionHeight + UIConstants.bigOffset,
            right: 0
        )
        return view
    }()

    let symbolView = SymbolView()

    let methodNameLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorStrokeGray()
        label.textAlignment = .center
        return label
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
        label.textAlignment = .center
        return label
    }()

    var walletView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.font = .p1Paragraph
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.iconView.image = R.image.iconBirdGreen()
        view.strokeColor = R.color.colorWhite8()!
        view.borderWidth = 1
        view.layout = .singleTitle
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

    let infoViewsStackView = {
        UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    }()

    lazy var dAppView: TitleValueView = {
        createMultiView()
    }()

    lazy var hostView: TitleValueView = {
        createMultiView()
    }()

    lazy var chainNameView: TitleValueView = {
        createMultiView()
    }()

    lazy var rawDataView: TitleValueView = {
        createMultiView()
    }()

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    var rawDataOnTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
        setupRawDataTap()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(viewModel: WalletConnectConfirmationViewModel) {
        symbolView.bind(viewModel: viewModel.symbolViewModel)
        methodNameLabel.text = viewModel.method
        amountLabel.text = viewModel.amount
        walletView.title = viewModel.walletName

        dAppView.valueLabel.text = viewModel.dApp
        hostView.valueLabel.text = viewModel.host
        chainNameView.valueLabel.text = viewModel.chain
        rawDataView.valueLabel.attributedText = viewModel.rawData
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(confirmButton)

        navigationBar.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
            make.height.equalTo(UIConstants.actionHeight)
        }

        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.leading.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
        }

        contentView.addArrangedSubview(symbolView)
        contentView.addArrangedSubview(methodNameLabel)
        contentView.addArrangedSubview(amountLabel)
        contentView.addArrangedSubview(walletView)
        contentView.addArrangedSubview(infoBackground)

        walletView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight54)
        }

        contentView.setCustomSpacing(UIConstants.accessoryItemsSpacing, after: amountLabel)
        contentView.setCustomSpacing(UIConstants.hugeOffset, after: walletView)
        contentView.setCustomSpacing(UIConstants.hugeOffset, after: infoBackground)

        [
            dAppView,
            hostView,
            chainNameView,
            rawDataView
        ].forEach { view in
            infoViewsStackView.addArrangedSubview(view)
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(UIConstants.cellHeight)
            }
        }
    }

    private func createMultiView() -> TitleValueView {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.valueLabel.lineBreakMode = .byTruncatingMiddle
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.commonPreview(preferredLanguages: locale.rLanguages))
        dAppView.titleLabel.text = "dApp"
        hostView.titleLabel.text = "host"
        chainNameView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages)
        rawDataView.titleLabel.text = R.string.localizable.commonTransactionRawData(preferredLanguages: locale.rLanguages)
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonSign(preferredLanguages: locale.rLanguages)
    }

    private func setupRawDataTap() {
        let tapGesture = UITapGestureRecognizer()
        tapGesture.addTarget(self, action: #selector(handleRawDataTapped))
        rawDataView.addGestureRecognizer(tapGesture)
        rawDataView.isUserInteractionEnabled = true
    }

    // MARK: - Private actions

    @objc private func handleRawDataTapped() {
        rawDataOnTap?()
    }
}
