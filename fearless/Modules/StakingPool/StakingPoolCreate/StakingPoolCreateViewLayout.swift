import UIKit
import SoraUI
import Kingfisher
import SnapKit

final class StakingPoolCreateViewLayout: UIView {
    private enum LayoutConstants {
        static let rawHeight: CGFloat = 64.0
        static let amountViewHeight: CGFloat = 92.0
        static let expandableIconSize = CGSize(width: 12, height: 6)
        static let expandableViewHeight: CGFloat = 368
    }

    var keyboardAdoptableConstraint: Constraint?

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

    let poolNameInputView = CommonInputViewV2()
    let amountView = AmountInputViewV2()

    let feeView: NetworkFeeFooterView = {
        let view = UIFactory.default.createNetworkFeeFooterView()
        view.backgroundColor = R.color.colorBlack19()
        view.networkFeeView?.borderType = .none
        return view
    }()

    let createButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            applyLocalization()
        }
    }

    // MARK: - Expandable view

    lazy var expandView: UIView = {
        createExpandView()
    }()

    let advancedContainer = UIView()
    let advancedTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h5Title
        return label
    }()

    let indicator: ImageActionIndicator = {
        let indicator = ImageActionIndicator()
        indicator.image = R.image.iconExpandable()
        return indicator
    }()

    let poolIdView: CommonInputViewV2 = createInputV2View()
    let depositorView: CommonInputViewV2 = createInputV2View()

    let rootAccountView: DetailsTriangularedView = createRoleView()
    let nominatorView: DetailsTriangularedView = createRoleView()
    let bouncerView: DetailsTriangularedView = createRoleView()

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        navigationBar.backButton.rounded()
    }

    // MARK: - Public methods

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        amountView.bind(viewModel: assetViewModel)
    }

    func bind(viewModel: StakingPoolCreateViewModel) {
        if let poolId = viewModel.poolId {
            poolIdView.text = "\(poolId)"
        }
        depositorView.text = viewModel.depositor
        rootAccountView.subtitle = viewModel.root
        nominatorView.subtitle = viewModel.naminator
        bouncerView.subtitle = viewModel.bouncer
    }

    // MARK: - Private actions

    @objc private func handleIndicatorTapped() {
        let isOpen = indicator.isActivated
        if isOpen {
            expandView.removeFromSuperview()
        } else {
            contentView.stackView.addArrangedSubview(expandView)
            expandView.snp.makeConstraints { make in
                make.height.equalTo(LayoutConstants.expandableViewHeight)
                make.leading.equalToSuperview().offset(UIConstants.bigOffset)
                make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            }
        }

        _ = isOpen ? indicator.deactivate() : indicator.activate()
    }

    // MARK: - Private methods

    private static func createRoleView() -> DetailsTriangularedView {
        let view = UIFactory.default.createAccountView(for: .selection, filled: true)
        view.layout = .withoutIcon
        view.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.strokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.highlightedStrokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.strokeWidth = 0.5
        view.titleLabel.font = .h5Title
        return view
    }

    private static func createInputV2View() -> CommonInputViewV2 {
        let view = CommonInputViewV2()
        view.animatedInputField.titleFont = .h5Title
        view.disable()
        return view
    }

    private func configure() {
        backgroundColor = R.color.colorBlack19()

        let gesture = UITapGestureRecognizer()
        gesture.addTarget(self, action: #selector(handleIndicatorTapped))
        advancedContainer.addGestureRecognizer(gesture)
    }

    private func applyLocalization() {
        feeView.locale = locale
        amountView.locale = locale

        navigationBar.setTitle(R.string.localizable.stakingPoolCreateTitle(
            preferredLanguages: locale.rLanguages
        ))
        feeView.actionButton.imageWithTitleView?.title = R.string.localizable.poolStakingJoinButtonTitle(
            preferredLanguages: locale.rLanguages
        )
        poolNameInputView.title = R.string.localizable.poolStakingPoolName(
            preferredLanguages: locale.rLanguages
        )
        advancedTitleLabel.text = R.string.localizable.commonAdvanced(
            preferredLanguages: locale.rLanguages
        )
        feeView.actionButton.imageWithTitleView?.title = R.string.localizable.commonCreate(
            preferredLanguages: locale.rLanguages
        )
        poolIdView.title = R.string.localizable.stakingPoolCreatePoolId(
            preferredLanguages: locale.rLanguages
        )
        depositorView.title = R.string.localizable.stakingPoolCreateDepositor(
            preferredLanguages: locale.rLanguages
        )
        rootAccountView.title = R.string.localizable.stakingPoolCreateRoot(
            preferredLanguages: locale.rLanguages
        )
        nominatorView.title = R.string.localizable.stakingPoolCreateNominator(
            preferredLanguages: locale.rLanguages
        )
        bouncerView.title = R.string.localizable.stakingPoolCreateStateToggler(
            preferredLanguages: locale.rLanguages
        )
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(feeView)

        contentView.stackView.addArrangedSubview(poolNameInputView)
        contentView.stackView.addArrangedSubview(amountView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
            make.bottom.equalTo(feeView.snp.top).offset(-UIConstants.bigOffset)
        }

        poolNameInputView.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.rawHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        amountView.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.amountViewHeight)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        contentView.stackView.addArrangedSubview(advancedContainer)
        advancedContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        advancedContainer.addSubview(advancedTitleLabel)
        advancedTitleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(UIConstants.verticalInset)
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview().inset(UIConstants.verticalInset)
        }

        advancedContainer.addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.size.equalTo(LayoutConstants.expandableIconSize)
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }

        feeView.networkFeeView?.borderType = .none
        feeView.networkFeeView?.borderView.borderType = .none

        feeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            keyboardAdoptableConstraint = make.bottom.equalTo(safeAreaLayoutGuide).constraint
        }
    }

    private func createExpandView() -> UIView {
        let vStackView = UIFactory.default.createVerticalStackView(spacing: 12)

        vStackView.addArrangedSubview(poolIdView)
        poolIdView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.rawHeight)
        }

        vStackView.addArrangedSubview(depositorView)
        depositorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.rawHeight)
        }

        vStackView.addArrangedSubview(rootAccountView)
        rootAccountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.rawHeight)
        }

        vStackView.addArrangedSubview(nominatorView)
        nominatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.rawHeight)
        }

        vStackView.addArrangedSubview(bouncerView)
        bouncerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(LayoutConstants.rawHeight)
        }

        return vStackView
    }
}
