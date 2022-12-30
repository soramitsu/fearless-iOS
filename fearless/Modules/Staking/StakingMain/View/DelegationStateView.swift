import SoraFoundation
class DelegationStateView: StakingStateView, LocalizableViewProtocol {
    private lazy var timer = CountdownTimer()
    private lazy var timeFormatter = TotalTimeFormatter()
    private var localizableViewModel: LocalizableResource<DelegationViewModelProtocol>?

    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    deinit {
        timer.stop()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
        timer.delegate = self
    }

    func bind(viewModel: LocalizableResource<DelegationViewModelProtocol>) {
        localizableViewModel = viewModel

        timer.stop()
        applyViewModel()
    }

    private func applyLocalization() {
        stakeTitleLabel.text = R.string.localizable
            .stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable
            .stakingFilterTitleRewardsApr(preferredLanguages: locale.rLanguages)
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            titleLabel.text = R.string.localizable
                .stakingYourStake(preferredLanguages: locale.rLanguages)
            return
        }

        statusView.valueView.detailsLabel.isHidden = viewModel.nextRoundInterval == nil

        titleLabel.text = viewModel.name == nil ?
            R.string.localizable.stakingYourStake(preferredLanguages: locale.rLanguages) : viewModel.name
        stakeAmountView.valueLabel.text = viewModel.totalStakedAmount
        stakeAmountView.subtitleLabel.text = viewModel.totalStakedPrice
        rewardAmountView.valueLabel.text = viewModel.apr

        toggleStatus(true)

        var skeletonOptions: StakingStateSkeletonOptions = []

        if viewModel.totalStakedAmount.isEmpty {
            skeletonOptions.insert(.stake)
        }

        if viewModel.apr.isEmpty {
            skeletonOptions.insert(.rewards)
        }

        switch viewModel.status {
        case let .active(round):
            presentActiveStatus(round: round)
        case let .idle(countdown):
            presentIdleStatus(countdown: countdown)
            if let interval = viewModel.nextRoundInterval {
                timer.start(with: interval, runLoop: RunLoop.current, mode: .tracking)
            }
        case let .leaving(countdown):
            presentLeavingState(countdown: countdown)
            if let interval = viewModel.nextRoundInterval {
                timer.start(with: interval, runLoop: RunLoop.current, mode: .tracking)
            }
        case .lowStake:
            presentLowStakeState()
        case .readyToUnlock:
            presentReadyToUnlock()
        case .undefined:
            skeletonOptions.insert(.status)
        }

        if !skeletonOptions.isEmpty, viewModel.hasPrice {
            skeletonOptions.insert(.price)
        }

        setupSkeleton(options: skeletonOptions)
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusView.isHidden = !shouldShow
        statusButton.isUserInteractionEnabled = shouldShow
    }

    private func presentActiveStatus(round: UInt32) {
        statusView.titleView.indicatorColor = R.color.colorGreen()!
        statusView.titleView.titleLabel.textColor = R.color.colorGreen()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusActive(preferredLanguages: locale.rLanguages).uppercased()
        statusView.valueView.detailsLabel.text = R.string.localizable
            .stakingRoundTitle("\(round)", preferredLanguages: locale.rLanguages).uppercased()
        statusView.valueView.imageView.isHidden = true
    }

    private func presentIdleStatus(countdown: TimeInterval?) {
        statusView.titleView.indicatorColor = R.color.colorRed()!
        statusView.titleView.titleLabel.textColor = R.color.colorRed()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusIdle(preferredLanguages: locale.rLanguages).uppercased()
        if let remainingTime = countdown {
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        }
    }

    private func presentLeavingState(countdown: TimeInterval?) {
        statusView.titleView.indicatorColor = R.color.colorRed()!
        statusView.titleView.titleLabel.textColor = R.color.colorRed()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusLeaving(preferredLanguages: locale.rLanguages).uppercased()
        if let remainingTime = countdown {
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        }
    }

    private func presentLowStakeState() {
        statusView.titleView.indicatorColor = R.color.colorRed()!
        statusView.titleView.titleLabel.textColor = R.color.colorRed()!

        statusView.titleView.titleLabel.text =
            R.string.localizable.stakingStatusLowStake(preferredLanguages: locale.rLanguages).uppercased()
    }

    private func presentReadyToUnlock() {
        statusView.titleView.indicatorColor = R.color.colorRed()!
        statusView.titleView.titleLabel.textColor = R.color.colorRed()!

        statusView.titleView.titleLabel.text =
            R.string.localizable.stakingStatusReadyToUnlock(preferredLanguages: locale.rLanguages).uppercased()
        statusView.valueView.imageView.isHidden = true
    }
}

extension DelegationStateView: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        let intervalString = (try? timeFormatter.string(from: interval)) ?? ""
        statusView.valueView.detailsLabel.text = "\(R.string.localizable.stakingNextRound(preferredLanguages: locale.rLanguages)): \(intervalString)"
    }

    func didCountdown(remainedInterval: TimeInterval) {
        let intervalString = (try? timeFormatter.string(from: remainedInterval)) ?? ""
        statusView.valueView.detailsLabel.text = "\(R.string.localizable.stakingNextRound(preferredLanguages: locale.rLanguages)): \(intervalString)"
    }

    func didStop(with _: TimeInterval) {
        statusView.valueView.detailsLabel.text = ""
    }
}
