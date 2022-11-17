import UIKit

final class StakingPoolInfoViewLayout: UIView {
    private enum LayoutConstants {
        static let roleViewHeight: CGFloat = 64
    }

    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
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

    let rolesTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .h4Title
        label.textAlignment = .left
        return label
    }()

    let infoStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

    let rolesBackground: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let roleStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)

    let indexView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        return view
    }()

    let nameView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        return view
    }()

    let stateView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        return view
    }()

    let stakedView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        return view
    }()

    let membersCountView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        return view
    }()

    let validatorsView: TitleValueView = {
        let view = TitleValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueLabel.font = .h5Title
        view.valueLabel.textColor = R.color.colorWhite()
        view.borderView.isHidden = true
        return view
    }()

    let roleDepositorView: DetailsTriangularedView = createRoleView()
    let roleRootView: DetailsTriangularedView = createRoleView()
    let roleNominatorView: DetailsTriangularedView = createRoleView()
    let roleStateTogglerView: DetailsTriangularedView = createRoleView()

    let saveRolesButton: TriangularedButton = {
        let button = UIFactory.default.createMainActionButton()
        button.isHidden = true
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

    private static func createRoleView() -> DetailsTriangularedView {
        let view = UIFactory.default.createAccountView(for: .selection, filled: true)
        view.layout = .withoutIcon
        view.triangularedBackgroundView?.fillColor = R.color.colorAlmostBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorAlmostBlack()!
        view.triangularedBackgroundView?.strokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.highlightedStrokeColor = R.color.colorWhite8()!
        view.triangularedBackgroundView?.strokeWidth = 0.5
        view.titleLabel.font = .h5Title
        view.actionView.isHidden = true

        return view
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.stackView.addArrangedSubview(infoBackground)
        contentView.stackView.addArrangedSubview(rolesTitleLabel)

        infoBackground.addSubview(infoStackView)
        infoStackView.addArrangedSubview(indexView)
        infoStackView.addArrangedSubview(nameView)
        infoStackView.addArrangedSubview(stateView)
        infoStackView.addArrangedSubview(stakedView)
        infoStackView.addArrangedSubview(membersCountView)
        infoStackView.addArrangedSubview(validatorsView)

        contentView.stackView.addArrangedSubview(roleDepositorView)
        contentView.stackView.addArrangedSubview(roleRootView)
        contentView.stackView.addArrangedSubview(roleNominatorView)
        contentView.stackView.addArrangedSubview(roleStateTogglerView)

        contentView.stackView.addArrangedSubview(saveRolesButton)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom)
        }

        infoBackground.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        rolesTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }

        infoStackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.accessoryItemsSpacing)
            make.trailing.equalToSuperview().inset(UIConstants.accessoryItemsSpacing)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        indexView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        nameView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        stateView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        stakedView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }
        membersCountView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        roleDepositorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.roleViewHeight)
        }

        roleRootView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.roleViewHeight)
        }

        roleNominatorView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.roleViewHeight)
        }

        roleStateTogglerView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.roleViewHeight)
        }

        validatorsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        saveRolesButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.stackView.setCustomSpacing(UIConstants.bigOffset, after: infoBackground)
        contentView.stackView.setCustomSpacing(UIConstants.defaultOffset, after: rolesTitleLabel)
    }

    private func applyLocalization() {
        indexView.titleLabel.text = R.string.localizable.indexCommon(
            preferredLanguages: locale.rLanguages
        )
        nameView.titleLabel.text = R.string.localizable.accountInfoNameTitle(
            preferredLanguages: locale.rLanguages
        )
        stateView.titleLabel.text = R.string.localizable.stateCommon(
            preferredLanguages: locale.rLanguages
        )
        stakedView.titleLabel.text = R.string.localizable.stakingMainStakeBalanceStaked(
            preferredLanguages: locale.rLanguages
        )
        membersCountView.titleLabel.text = R.string.localizable.membersCommon(
            preferredLanguages: locale.rLanguages
        )
        validatorsView.titleLabel.text = R.string.localizable.stakingRewardDetailsValidator(
            preferredLanguages: locale.rLanguages
        )

        roleDepositorView.title = R.string.localizable.poolStakingDepositor(
            preferredLanguages: locale.rLanguages
        )
        roleRootView.title = R.string.localizable.poolStakingRoot(
            preferredLanguages: locale.rLanguages
        )
        roleNominatorView.title = R.string.localizable.poolStakingNominator(
            preferredLanguages: locale.rLanguages
        )
        roleStateTogglerView.title = R.string.localizable.poolStakingStateToggler(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.stakingPoolInfoTitle(
            preferredLanguages: locale.rLanguages
        ))
        rolesTitleLabel.text = R.string.localizable.rolesCommon(preferredLanguages: locale.rLanguages)
        saveRolesButton.imageWithTitleView?.title = R.string.localizable.commonSave(
            preferredLanguages: locale.rLanguages
        )
    }

    private func applySelectableStyle(selectable: Bool, for view: DetailsTriangularedView) {
        view.actionView.isHidden = !selectable
        view.isUserInteractionEnabled = selectable
        let backgroundColor = selectable ? R.color.colorSemiBlack()! : R.color.colorAlmostBlack()!
        view.triangularedBackgroundView?.fillColor = backgroundColor
        view.triangularedBackgroundView?.highlightedFillColor = backgroundColor
    }

    func bind(viewModel: StakingPoolInfoViewModel) {
        indexView.valueLabel.text = viewModel.indexTitle
        nameView.valueLabel.text = viewModel.name
        stateView.valueLabel.text = viewModel.state
        stakedView.valueTop.text = viewModel.stakedAmountViewModel?.amount
        stakedView.valueBottom.text = viewModel.stakedAmountViewModel?.price
        membersCountView.valueLabel.text = viewModel.membersCountTitle
        validatorsView.valueLabel.attributedText = viewModel.validatorsCountAttributedString

        roleDepositorView.subtitle = viewModel.depositorName
        roleRootView.subtitle = viewModel.rootName
        roleNominatorView.subtitle = viewModel.nominatorName
        roleStateTogglerView.subtitle = viewModel.stateTogglerName

        saveRolesButton.isHidden = !viewModel.rolesChanged

        applySelectableStyle(selectable: viewModel.userIsRoot, for: roleRootView)
        applySelectableStyle(selectable: viewModel.userIsRoot, for: roleNominatorView)
        applySelectableStyle(selectable: viewModel.userIsRoot, for: roleStateTogglerView)
    }
}
