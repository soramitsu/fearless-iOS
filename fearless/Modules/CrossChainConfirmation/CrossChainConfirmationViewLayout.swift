import UIKit

final class CrossChainConfirmationViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.backButton.backgroundColor = R.color.colorWhite8()
        bar.backgroundColor = R.color.colorBlack02()
        return bar
    }()

    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let symbolView = SymbolView()

    let teleportStubLabel: UILabel = {
        let label = UILabel()
        label.font = .h2Title
        label.textColor = R.color.colorStrokeGray()
        return label
    }()

    let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .h1Title
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

    let infoViewsStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    let originalNetworkView = UIFactory.default.createConfirmationMultiView()
    let destNetworkView = UIFactory.default.createConfirmationMultiView()
    let amountView = UIFactory.default.createConfirmationMultiView()
    let originalChainFeeView = UIFactory.default.createConfirmationMultiView()
    let destChainFeeView = UIFactory.default.createConfirmationMultiView()

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

    func bind(confirmViewModel: CrossChainConfirmationViewModel) {
        symbolView.bind(viewModel: confirmViewModel.symbolViewModel)
        amountLabel.text = confirmViewModel.amount.amount
        originalNetworkView.valueTop.text = confirmViewModel.originalNetworkName
        destNetworkView.valueTop.text = confirmViewModel.destNetworkName
        amountView.bindBalance(viewModel: confirmViewModel.amount)
        originalChainFeeView.bindBalance(viewModel: confirmViewModel.originalChainFee)
        destChainFeeView.bindBalance(viewModel: confirmViewModel.destChainFee)
    }

    private func configure() {
        originalNetworkView.valueBottom.lineBreakMode = .byTruncatingMiddle
        originalNetworkView.valueBottom.textAlignment = .right
        originalNetworkView.valueTop.textAlignment = .right
        destNetworkView.valueTop.lineBreakMode = .byTruncatingMiddle
        destNetworkView.valueTop.textAlignment = .right
        amountView.valueBottom.textAlignment = .right
        amountView.valueTop.textAlignment = .right
        originalChainFeeView.valueBottom.textAlignment = .right
        originalChainFeeView.valueTop.textAlignment = .right
        destChainFeeView.valueBottom.textAlignment = .right
        destChainFeeView.valueTop.textAlignment = .right
        originalNetworkView.borderView.isHidden = true
        destNetworkView.borderView.isHidden = true
        amountView.borderView.isHidden = true
        originalChainFeeView.borderView.isHidden = true
        destChainFeeView.borderView.isHidden = true
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.commonPreview(
            preferredLanguages: locale.rLanguages
        ))
        teleportStubLabel.text = "Teleport"
        originalNetworkView.titleLabel.text = "Original network"
        destNetworkView.titleLabel.text = "Destination network"
        amountView.titleLabel.text = R.string.localizable.walletSendAmountTitle(
            preferredLanguages: locale.rLanguages
        )
        originalChainFeeView.titleLabel.text = "Origin Chain Fee"
        destChainFeeView.titleLabel.text = "Destination Chain Fee"
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(confirmButton)

        contentView.stackView.addArrangedSubview(symbolView)
        contentView.stackView.addArrangedSubview(teleportStubLabel)
        contentView.stackView.addArrangedSubview(amountLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        infoBackground.addSubview(infoViewsStackView)
        infoViewsStackView.addArrangedSubview(originalNetworkView)
        infoViewsStackView.addArrangedSubview(destNetworkView)
        infoViewsStackView.addArrangedSubview(amountView)
        infoViewsStackView.addArrangedSubview(originalChainFeeView)
        infoViewsStackView.addArrangedSubview(destChainFeeView)

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

        func makeCellHeightConstraints(for view: UIView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(UIConstants.cellHeight)
            }
        }

        [
            originalNetworkView,
            destNetworkView,
            amountView,
            originalChainFeeView,
            destChainFeeView
        ].forEach { makeCellHeightConstraints(for: $0) }
    }
}
