import UIKit

final class PoolRolesConfirmViewLayout: UIView {
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

    let titleLabel: UILabel = {
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
    lazy var rootView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var nominatorView: TitleMultiValueView = {
        createMultiView()
    }()

    lazy var stateTogglerView: TitleMultiValueView = {
        createMultiView()
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

    let confirmButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let hintView: IconDetailsView = {
        let view = IconDetailsView()
        view.iconWidth = UIConstants.iconSize
        view.imageView.contentMode = .top
        view.imageView.image = R.image.iconWarning()
        return view
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    lazy var multiViews: [TitleMultiValueView] = {
        [
            rootView,
            nominatorView,
            stateTogglerView
        ]
    }()

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

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        feeView.bind(viewModel: feeViewModel)
    }

    func bind(viewModel: PoolRolesConfirmViewModel) {
        rootView.bind(viewModel: viewModel.rootViewModel)
        nominatorView.bind(viewModel: viewModel.nominatorViewModel)
        stateTogglerView.bind(viewModel: viewModel.stateTogglerViewModel)
    }

    private func configure() {
        func configure(view: TitleMultiValueView) {
            view.valueBottom.lineBreakMode = .byTruncatingMiddle
            view.valueBottom.textAlignment = .right
            view.valueTop.textAlignment = .right
            view.borderView.isHidden = true
        }

        multiViews.forEach { configure(view: $0) }

        feeView.borderType = .none
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable.poolUpdateRolesTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        ))

        rootView.titleLabel.text = R.string.localizable.poolStakingRoot(
            preferredLanguages: locale.rLanguages
        )
        nominatorView.titleLabel.text = R.string.localizable.poolStakingNominator(
            preferredLanguages: locale.rLanguages
        )
        stateTogglerView.titleLabel.text = R.string.localizable.poolStakingStateToggler(
            preferredLanguages: locale.rLanguages
        )
        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )
        confirmButton.imageWithTitleView?.title = R.string.localizable.commonConfirm(
            preferredLanguages: locale.rLanguages
        )
        hintView.detailsLabel.text = R.string.localizable.poolUpdateRolesWarning(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        func makeMultiViewConstraints(view: TitleMultiValueView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
                make.height.equalTo(UIConstants.cellHeight)
            }
        }

        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(hintView)
        addSubview(confirmButton)

        contentView.stackView.addArrangedSubview(iconImageView)
        contentView.stackView.addArrangedSubview(titleLabel)
        contentView.stackView.addArrangedSubview(infoBackground)

        infoBackground.addSubview(infoViewsStackView)
        multiViews.forEach { infoViewsStackView.addArrangedSubview($0) }
        infoViewsStackView.addArrangedSubview(feeView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(hintView.snp.top).offset(-UIConstants.bigOffset)
        }

        hintView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(confirmButton.snp.top).offset(-UIConstants.bigOffset)
        }

        confirmButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        infoBackground.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoViewsStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
            make.top.equalToSuperview().inset(UIConstants.bigOffset)
        }

        multiViews.forEach { makeMultiViewConstraints(view: $0) }

        feeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }
    }

    private func createMultiView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueTop.lineBreakMode = .byTruncatingMiddle
        view.valueTop.numberOfLines = 2
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        view.valueBottom.numberOfLines = 2
        return view
    }
}
