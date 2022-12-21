import UIKit

final class PolkaswapTransaktionSettingsViewLayout: UIView {
    private enum Constants {
        static let navigationBarHeight: CGFloat = 56.0
        static let backButtonSize = CGSize(width: 32, height: 32)
        static let contentSpacing: CGFloat = 12.0
        static let minimumSliderValue: Float = 0
        static let maximumSliderValue: Float = 10
        static let spacerHeight: CGFloat = 120.0
        static let rowHeight: CGFloat = 64.0
    }

    private let navigationViewContainer = UIView()

    let backButton: UIButton = {
        let button = UIButton()
        button.setImage(R.image.iconBack(), for: .normal)
        button.layer.masksToBounds = true
        button.backgroundColor = R.color.colorWhite8()
        return button
    }()

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        return label
    }()

    let contentStackView: UIStackView = {
        let stack = UIFactory.default
            .createVerticalStackView(spacing: Constants.contentSpacing)
        return stack
    }()

    let selectMarketView: DetailsTriangularedView = {
        let view = UIFactory.default.createNetworkView(selectable: true)
        view.layout = .withoutIcon
        view.iconView.image = R.image.iconDropDown()
        return view
    }()

    let slippageToleranceView = SlippageToleranceView()

    let slippageToleranceSlider: UISlider = {
        let view = UISlider()
        view.minimumValue = Constants.minimumSliderValue
        view.maximumValue = Constants.maximumSliderValue
        view.isContinuous = true
        view.tintColor = R.color.colorPink()
        return view
    }()

    let slippageToleranceTitle: UILabel = {
        let label = UILabel()
        label.font = .p2Paragraph
        label.textColor = R.color.colorStrokeGray()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    let revertButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDisabledStyle()
        return button
    }()

    let saveButton = UIFactory.default.createMainActionButton()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = R.color.colorBlack19()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backButton.rounded()
    }

    // MARK: - Public methods

    func bind(market: String) {
        selectMarketView.subtitle = market
    }

    func bind(viewModel: SlippageToleranceViewModel) {
        slippageToleranceView.bind(with: viewModel)
        slippageToleranceSlider.setValue(viewModel.value, animated: true)
    }

    // MARK: - Private methods

    private func setupLayout() {
        func makeCommonConstraints(for view: UIView) {
            view.snp.makeConstraints { make in
                make.leading.trailing.equalToSuperview()
            }
        }
        addSubview(navigationViewContainer)
        navigationViewContainer.addSubview(backButton)
        navigationViewContainer.addSubview(titleLabel)
        navigationViewContainer.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(Constants.navigationBarHeight)
        }

        backButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.equalTo(UIConstants.bigOffset)
            make.size.equalTo(Constants.backButtonSize)
        }

        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualTo(backButton.snp.trailing)
        }

        addSubview(contentStackView)
        contentStackView.snp.makeConstraints { make in
            make.top.equalTo(navigationViewContainer.snp.bottom)
                .offset(UIConstants.accessoryItemsSpacing)
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.bottom.equalTo(safeAreaLayoutGuide)
        }

        let spacer = UIView()
        spacer.snp.makeConstraints { make in
            make.height.equalTo(Constants.spacerHeight)
        }

        slippageToleranceView.isUserInteractionEnabled = false
        contentStackView.addArrangedSubview(selectMarketView)
        contentStackView.addArrangedSubview(slippageToleranceView)
        contentStackView.addArrangedSubview(slippageToleranceSlider)
        contentStackView.addArrangedSubview(slippageToleranceTitle)
        contentStackView.addArrangedSubview(spacer)
        contentStackView.addArrangedSubview(revertButton)
        contentStackView.addArrangedSubview(saveButton)

        [selectMarketView, slippageToleranceView].forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(Constants.rowHeight)
            }
        }

        [revertButton, saveButton].forEach {
            $0.snp.makeConstraints { make in
                make.height.equalTo(UIConstants.actionHeight)
            }
        }

        let contentViews: [UIView] = [
            selectMarketView,
            slippageToleranceView,
            slippageToleranceSlider,
            slippageToleranceTitle,
            revertButton,
            saveButton
        ]
        contentViews.forEach { makeCommonConstraints(for: $0) }
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .polkaswapSettingsTitle(preferredLanguages: locale.rLanguages)
        selectMarketView.title = R.string.localizable
            .polkaswapMarketStub(preferredLanguages: locale.rLanguages)
        saveButton.imageWithTitleView?.title = R.string.localizable
            .commonSave(preferredLanguages: locale.rLanguages)
        revertButton.imageWithTitleView?.title = R.string.localizable
            .polkaswapSettingsReset(preferredLanguages: locale.rLanguages)
        slippageToleranceTitle.text = R.string.localizable
            .polkaswapSettingsSlippageStub(preferredLanguages: locale.rLanguages)
        slippageToleranceView.titleLabel.text = R.string.localizable
            .polkaswapSettingsSlippageTitle(preferredLanguages: locale.rLanguages)
    }
}
