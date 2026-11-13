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

    /// The rows of the request, in the order the view model gives them.
    private(set) var rowViews: [TitleValueView] = []

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

        rowViews.forEach { $0.removeFromSuperview() }
        rowViews = viewModel.rows.map { row in
            let view = createMultiView()
            view.titleLabel.text = row.title
            view.valueLabel.text = row.value
            if row.isMultiline {
                view.valueLabel.numberOfLines = 0
                view.valueLabel.lineBreakMode = .byWordWrapping
            }
            if row.isWarning {
                view.titleLabel.textColor = R.color.colorOrange()
                view.valueLabel.textColor = R.color.colorOrange()
            }
            return view
        }

        for (index, rowView) in rowViews.enumerated() {
            infoViewsStackView.insertArrangedSubview(rowView, at: index)
            rowView.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.greaterThanOrEqualTo(UIConstants.cellHeight)
            }
        }

        rawDataView.valueLabel.attributedText = viewModel.rawData
    }

    // MARK: - Private methods

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(confirmButton)

        navigationBar.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalTo(safeAreaLayoutGuide)
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        confirmButton.snp.makeConstraints { make in
            make.leading.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
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
        contentView.addArrangedSubview(infoBackground)

        infoBackground.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }

        contentView.setCustomSpacing(UIConstants.hugeOffset, after: methodNameLabel)
        contentView.setCustomSpacing(UIConstants.hugeOffset, after: infoBackground)

        infoViewsStackView.addArrangedSubview(rawDataView)
        rawDataView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }
    }

    private func createMultiView() -> TitleValueView {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.titleLabel.setContentHuggingPriority(.required, for: .horizontal)
        view.titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.valueLabel.lineBreakMode = .byTruncatingMiddle
        view.borderView.isHidden = true
        return view
    }

    private func applyLocalization() {
        navigationBar.setTitle(R.string.localizable.commonPreview(preferredLanguages: locale.rLanguages))
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
