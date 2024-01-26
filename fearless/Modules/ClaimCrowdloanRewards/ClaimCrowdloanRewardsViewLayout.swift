import UIKit

final class ClaimCrowdloanRewardsViewLayout: UIView {
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

    let totalRewardsView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        view.valueTop.lineBreakMode = .byTruncatingTail
        view.valueBottom.lineBreakMode = .byTruncatingMiddle
        return view
    }()

    let claimableRewardsView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let lockedRewardsView: TitleMultiValueView = {
        let view = TitleMultiValueView()
        view.titleLabel.font = .h5Title
        view.titleLabel.textColor = R.color.colorStrokeGray()
        view.valueTop.font = .h5Title
        view.valueTop.textColor = R.color.colorWhite()
        view.valueBottom.font = .p1Paragraph
        view.valueBottom.textColor = R.color.colorStrokeGray()
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
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
        view.borderView.isHidden = true
        view.equalsLabelsWidth = true
        return view
    }()

    let stakeAmountView = StakeAmountView()

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

    let infoStackView = UIFactory.default.createVerticalStackView(spacing: UIConstants.bigOffset)
    let networkFeeFooterView = UIFactory().createCleanNetworkFeeFooterView()
    let hintView = IconDetailsView()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayout()

        backgroundColor = R.color.colorBlack19()
        contentView.backgroundColor = R.color.colorBlack19()
        navigationBar.backgroundColor = R.color.colorBlack19()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.rounded()
    }

    func bind(hintViewModel: TitleIconViewModel?) {
        hintView.iconWidth = UIConstants.iconSize
        hintView.detailsLabel.text = hintViewModel?.title
        hintView.imageView.image = hintViewModel?.icon
    }

    private func setupLayout() {
        addSubview(contentView)
        addSubview(navigationBar)
        addSubview(networkFeeFooterView)
        addSubview(hintView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        contentView.snp.makeConstraints { make in
            make.top.equalTo(navigationBar.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(stakeAmountView)
        contentView.stackView.addArrangedSubview(infoBackground)
        infoBackground.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
        }
        infoBackground.addSubview(infoStackView)
        infoStackView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.bottom.equalToSuperview().inset(UIConstants.defaultOffset)
        }

        infoStackView.addArrangedSubview(totalRewardsView)
        infoStackView.addArrangedSubview(lockedRewardsView)
        infoStackView.addArrangedSubview(claimableRewardsView)
        infoStackView.addArrangedSubview(feeView)

        totalRewardsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        lockedRewardsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        claimableRewardsView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        feeView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(UIConstants.cellHeight)
        }

        hintView.snp.makeConstraints { make in
            make.top.equalTo(contentView.snp.bottom)
            make.leading.trailing.equalToSuperview()
        }

        networkFeeFooterView.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(hintView.snp.bottom).offset(16)
        }
    }

    private func applyLocalization() {
        totalRewardsView.titleLabel.text = R.string.localizable.stakingRewardsTitle(preferredLanguages: locale.rLanguages)
        lockedRewardsView.titleLabel.text = R.string.localizable.walletBalanceLocked(preferredLanguages: locale.rLanguages)
        claimableRewardsView.titleLabel.text = R.string.localizable.poolClaimableTitle(preferredLanguages: locale.rLanguages)

        feeView.titleLabel.text = R.string.localizable.commonNetworkFee(
            preferredLanguages: locale.rLanguages
        )
        networkFeeFooterView.locale = locale

        navigationBar.setTitle(R.string.localizable.poolStakingManagementClaimTitle(preferredLanguages: locale.rLanguages))
        setNeedsLayout()
    }
}
