import UIKit

final class BalanceLocksDetailViewLayout: UIView {
    let navigationBar: BaseNavigationBar = {
        let bar = BaseNavigationBar()
        bar.set(.present)
        bar.backButtonAlignment = .right
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

    let stakingBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let poolsBackgroundView: TriangularedView = {
        let view = TriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.strokeColor = R.color.colorWhite16()!
        view.highlightedStrokeColor = R.color.colorWhite16()!
        view.strokeWidth = 0.5
        view.shadowOpacity = 0.0

        return view
    }()

    let stakingTitleRowView: RowView<UILabel> = {
        let label = makeSectionTitleLabel()
        return RowView(contentView: label)
    }()

    let poolsTitleRowView: RowView<UILabel> = {
        let label = makeSectionTitleLabel()
        return RowView(contentView: label)
    }()

    let frozenView = makeSectionView()
    let blockedView = makeSectionView()
    let stakingStackView = UIFactory.default.createVerticalStackView()
    let stakingStakedRowView = makeRowView()
    let stakingUnstakingRowView = makeRowView()
    let stakingRedeemableRowView = makeRowView()
    let poolsStackView = UIFactory.default.createVerticalStackView()
    let poolsStakedRowView = makeRowView()
    let poolsUnstakingRowView = makeRowView()
    let poolsRedeemableRowView = makeRowView()
    let poolsClaimableRowView = makeRowView()

    let liquidityPoolsView = makeSectionView()
    let crowdloansView = makeSectionView()
    let governanceView = makeSectionView()
    let totalView = makeSectionView()

    var locale: Locale = .current {
        didSet {
            applyLocalization()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack19()
        drawSubviews()
        setupConstraints()
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

    private func drawSubviews() {
        addSubview(navigationBar)
        addSubview(contentView)

        contentView.addArrangedSubview(stakingBackgroundView)
        stakingBackgroundView.addSubview(stakingStackView)
        stakingStackView.addArrangedSubview(stakingTitleRowView)
        stakingStackView.addArrangedSubview(stakingStakedRowView)
        stakingStackView.addArrangedSubview(stakingUnstakingRowView)
        stakingStackView.addArrangedSubview(stakingRedeemableRowView)
        contentView.addArrangedSubview(poolsBackgroundView)
        poolsBackgroundView.addSubview(poolsStackView)
        poolsStackView.addArrangedSubview(poolsTitleRowView)
        poolsStackView.addArrangedSubview(poolsStakedRowView)
        poolsStackView.addArrangedSubview(poolsUnstakingRowView)
        poolsStackView.addArrangedSubview(poolsRedeemableRowView)
        poolsStackView.addArrangedSubview(poolsClaimableRowView)
        contentView.addArrangedSubview(liquidityPoolsView)
        contentView.addArrangedSubview(crowdloansView)
        contentView.addArrangedSubview(governanceView)
        contentView.addArrangedSubview(frozenView)
        contentView.addArrangedSubview(blockedView)
        contentView.addArrangedSubview(totalView)

        liquidityPoolsView.isHidden = true
    }

    private func setupConstraints() {
        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }
        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }

        stakingStackView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(8)
        }

        poolsStackView.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
            make.bottom.equalToSuperview().inset(8)
        }

        stakingBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
        }

        poolsBackgroundView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
        }

        stakingTitleRowView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(43)
        }

        stakingTitleRowView.contentView!.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        poolsTitleRowView.contentView!.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(16)
        }

        poolsTitleRowView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(43)
        }

        [
            stakingStakedRowView,
            stakingUnstakingRowView,
            stakingRedeemableRowView,
            poolsStakedRowView,
            poolsUnstakingRowView,
            poolsRedeemableRowView,
            poolsClaimableRowView
        ].forEach { view in
            setupDefaultRowConstraints(for: view)
        }

        [
            liquidityPoolsView,
            crowdloansView,
            governanceView,
            totalView,
            frozenView,
            blockedView
        ].forEach { view in
            setupDefaultSectionConstraints(for: view)
        }
    }

    private func setupDefaultRowConstraints(for view: UIView) {
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
        }
    }

    private func setupDefaultSectionConstraints(for view: UIView) {
        view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(56)
        }
    }

    private func applyLocalization() {
        navigationBar.titleLabel.text = R.string.localizable.assetdetailsBalanceLocked(preferredLanguages: locale.rLanguages)
        stakingStakedRowView.titleLabel.text = R.string.localizable.stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        stakingUnstakingRowView.titleLabel.text = R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: locale.rLanguages)
        stakingRedeemableRowView.titleLabel.text = R.string.localizable.walletBalanceRedeemable(preferredLanguages: locale.rLanguages)
        poolsStakedRowView.titleLabel.text = R.string.localizable.stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        poolsUnstakingRowView.titleLabel.text = R.string.localizable.walletBalanceUnbonding_v190(preferredLanguages: locale.rLanguages)
        poolsRedeemableRowView.titleLabel.text = R.string.localizable.walletBalanceRedeemable(preferredLanguages: locale.rLanguages)
        poolsClaimableRowView.titleLabel.text = R.string.localizable.poolClaimableTitle(preferredLanguages: locale.rLanguages)
        liquidityPoolsView.titleLabel.text = R.string.localizable.balanceLocksLiquidityPoolsRowTitle(preferredLanguages: locale.rLanguages)
        crowdloansView.titleLabel.text = R.string.localizable.tabbarCrowdloanTitle(preferredLanguages: locale.rLanguages)
        governanceView.titleLabel.text = R.string.localizable.balanceLocksGovernanceRowTitle(preferredLanguages: locale.rLanguages)
        totalView.titleLabel.text = R.string.localizable.commonTotal(preferredLanguages: locale.rLanguages)
        poolsTitleRowView.rowContentView.text = R.string.localizable.balanceLocksNominationPoolsRowTitle(preferredLanguages: locale.rLanguages)
        stakingTitleRowView.rowContentView.text = R.string.localizable.commonStaking(preferredLanguages: locale.rLanguages)
        frozenView.titleLabel.text = R.string.localizable.walletBalanceFrozen(preferredLanguages: locale.rLanguages)
        blockedView.titleLabel.text = R.string.localizable.balanceLocksBlockedRowTitle(preferredLanguages: locale.rLanguages)
        navigationBar.setTitle(R.string.localizable.balanceLocksScreenTitle(preferredLanguages: locale.rLanguages))
    }

    private static func makeSectionTitleLabel() -> UILabel {
        let label = UILabel()
        label.font = .h5Title
        label.textColor = R.color.colorWhite()
        return label
    }

    private static func makeRowView() -> TitleMultiValueView {
        let view = TitleMultiValueView()
        view.titleLabel.font = .p1Paragraph
        view.titleLabel.textColor = R.color.colorWhite()
        view.valueTop.font = .p1Paragraph
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p2Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        view.valueTop.lineBreakMode = .byTruncatingTail
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }

    private static func makeSectionView() -> TriangularedTitleMultiValueView {
        let view = TriangularedTitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorWhite()
        view.valueTop.font = .p1Paragraph
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p2Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.equalsLabelsWidth = true
        view.borderView.isHidden = true
        view.valueTop.lineBreakMode = .byTruncatingTail
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }
}
