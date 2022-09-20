import UIKit

final class StakingPoolStartViewLayout: UIView {
    private enum LayoutConstants {
        static let earnRewardsLabelHeight: CGFloat = 104.0

        static let whatIsStakingViewHeight: CGFloat = 46.0
        static let delayViewHeight: CGFloat = 64.0
        static let estimatedRewardViewHeight: CGFloat = 44.0
        static let unstakePeriodViewHeight: CGFloat = 104.0
        static let rewardsFreqViewHeight: CGFloat = 44.0
    }

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
        view.stackView.layoutMargins = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 0.0, right: 0.0)
        view.stackView.spacing = UIConstants.bigOffset
        return view
    }()

    let whatIsStakingView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.fillColor = R.color.colorSemiBlack()!
        view.highlightedFillColor = R.color.colorSemiBlack()!
        view.iconImage = R.image.iconBook()
        view.titleLabel.font = .h6Title
        view.titleLabel.textColor = .white.withAlphaComponent(0.5)
        view.titleLabel.numberOfLines = 0
        view.layout = .smallIconTitleButton
        view.isUserInteractionEnabled = true
        view.contentView?.isUserInteractionEnabled = true
        view.backgroundView?.isUserInteractionEnabled = true

        return view
    }()

    let earnRewardsLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = R.color.colorStrokeGray()
        label.font = .h2Title
        return label
    }()

    let delayView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.numberOfLines = 0
        view.titleLabel.font = .h4Title
        view.layout = .singleTitle

        return view
    }()

    let estimatedRewardView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.numberOfLines = 0
        view.titleLabel.font = .h4Title
        view.layout = .singleTitle

        return view
    }()

    let unstakePeriodView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.numberOfLines = 4
        view.titleLabel.font = .h4Title
        view.layout = .singleTitle

        return view
    }()

    let rewardsFreqView: DetailsTriangularedView = {
        let view = DetailsTriangularedView()
        view.triangularedBackgroundView?.fillColor = R.color.colorSemiBlack()!
        view.triangularedBackgroundView?.highlightedFillColor = R.color.colorSemiBlack()!
        view.titleLabel.numberOfLines = 0
        view.titleLabel.font = .h4Title
        view.layout = .singleTitle

        return view
    }()

    let joinButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        return button
    }()

    let createButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyEnabledStyle()
        button.triangularedView?.fillColor = R.color.colorBlack1()!
        button.triangularedView?.highlightedFillColor = R.color.colorBlack1()!
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
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        navigationBar.backButton.layer.cornerRadius = navigationBar.backButton.frame.size.height / 2
    }

    private func applyLocalization() {
        joinButton.imageWithTitleView?.title = R.string.localizable.poolStakingJoinTitle(
            preferredLanguages: locale.rLanguages
        )
        createButton.imageWithTitleView?.title = R.string.localizable.stakingPoolStartCreateButtonTitle(
            preferredLanguages: locale.rLanguages
        )
        whatIsStakingView.title = R.string.localizable.poolStakingStartAboutTitle(
            preferredLanguages: locale.rLanguages
        )
        whatIsStakingView.actionButton?.imageWithTitleView?.title = R.string.localizable.commonWatch(
            preferredLanguages: locale.rLanguages
        )
        navigationBar.setTitle(R.string.localizable.poolStakingTitle(
            preferredLanguages: locale.rLanguages
        ))
    }

    private func setupLayout() {
        addSubview(navigationBar)
        addSubview(contentView)
        addSubview(joinButton)
        addSubview(createButton)

        contentView.stackView.addArrangedSubview(whatIsStakingView)
        contentView.stackView.addArrangedSubview(earnRewardsLabel)
        contentView.stackView.addArrangedSubview(delayView)
        contentView.stackView.addArrangedSubview(estimatedRewardView)
        contentView.stackView.addArrangedSubview(unstakePeriodView)
        contentView.stackView.addArrangedSubview(rewardsFreqView)

        navigationBar.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        createButton.snp.makeConstraints { make in
            make.bottom.trailing.equalTo(safeAreaLayoutGuide).inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
            make.top.equalTo(joinButton.snp.bottom).offset(UIConstants.defaultOffset)
        }

        joinButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(navigationBar.snp.bottom).offset(UIConstants.bigOffset)
            make.bottom.equalTo(joinButton.snp.top).inset(UIConstants.bigOffset)
        }

        whatIsStakingView.snp.makeConstraints { make in
            make.height.equalTo(LayoutConstants.whatIsStakingViewHeight)
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
        }

        earnRewardsLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.earnRewardsLabelHeight)
        }

        delayView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.delayViewHeight)
        }

        estimatedRewardView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.estimatedRewardViewHeight)
        }

        unstakePeriodView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.unstakePeriodViewHeight)
        }

        rewardsFreqView.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(UIConstants.bigOffset)
            make.leading.equalToSuperview().offset(UIConstants.bigOffset)
            make.height.equalTo(LayoutConstants.rewardsFreqViewHeight)
        }
    }

    func bind(viewModel: StakingPoolStartViewModel) {
        earnRewardsLabel.attributedText = viewModel.descriptionText
        delayView.iconImage = viewModel.delayDetailsViewModel?.icon
        delayView.titleLabel.attributedText = viewModel.delayDetailsViewModel?.title
        estimatedRewardView.iconImage = viewModel.estimatedRewardViewModel?.icon
        unstakePeriodView.iconImage = viewModel.unstakePeriodViewModel?.icon
        unstakePeriodView.titleLabel.attributedText = viewModel.unstakePeriodViewModel?.title
        rewardsFreqView.iconImage = viewModel.rewardsFreqViewModel?.icon
        rewardsFreqView.titleLabel.attributedText = viewModel.rewardsFreqViewModel?.title

        if let estimatedRewardTitle = viewModel.estimatedRewardViewModel?.title {
            estimatedRewardView.titleLabel.apply(state: .normalAttributed(estimatedRewardTitle))
        } else {
            estimatedRewardView.titleLabel.apply(state: .updating(R.string.localizable.stakingValidatorEstimatedReward(preferredLanguages: locale.rLanguages)))
        }
    }
}
