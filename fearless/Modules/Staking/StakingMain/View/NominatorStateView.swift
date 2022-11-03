import Foundation
import SoraFoundation

class NominatorStateView: StakingStateView, LocalizableViewProtocol {
    private lazy var timer = CountdownTimer()
    private lazy var timeFormatter = TotalTimeFormatter()
    private var localizableViewModel: LocalizableResource<NominationViewModelProtocol>?

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

    func bind(viewModel: LocalizableResource<NominationViewModelProtocol>) {
        localizableViewModel = viewModel

        timer.stop()
        applyViewModel()
    }

    private func applyLocalization() {
        stakeTitleLabel.text = R.string.localizable
            .stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable
            .stakingTotalRewards_v190(preferredLanguages: locale.rLanguages)
        redeemableView.titleLabel.text = R.string.localizable.walletBalanceRedeemable(
            preferredLanguages: locale.rLanguages
        )
        unstakingView.titleLabel.text = R.string.localizable.walletBalanceUnbonding_v190(
            preferredLanguages: locale.rLanguages
        )
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            titleLabel.text = R.string.localizable
                .stakingYourStake(preferredLanguages: locale.rLanguages)
            return
        }

        titleLabel.text = R.string.localizable.stakingYourStake(preferredLanguages: locale.rLanguages)
        stakeAmountView.valueLabel.text = viewModel.totalStakedAmount
        stakeAmountView.subtitleLabel.text = viewModel.totalStakedPrice
        rewardAmountView.valueLabel.text = viewModel.totalRewardAmount
        rewardAmountView.subtitleLabel.text = viewModel.totalRewardPrice

        redeemableView.valueLabel.text = viewModel.redeemableViewModel?.value
        redeemableView.subtitleLabel.text = viewModel.redeemableViewModel?.subtitle

        unstakingView.valueLabel.text = viewModel.unstakingViewModel?.value
        unstakingView.subtitleLabel.text = viewModel.unstakingViewModel?.subtitle

        redeemableView.isHidden = viewModel.redeemableViewModel == nil
        unstakingView.isHidden = viewModel.unstakingViewModel == nil

        if case .undefined = viewModel.status {
            toggleStatus(false)
        } else {
            toggleStatus(true)
        }

        var skeletonOptions: StakingStateSkeletonOptions = []

        if viewModel.totalStakedAmount.isEmpty {
            skeletonOptions.insert(.stake)
        }

        if viewModel.totalRewardAmount.isEmpty {
            skeletonOptions.insert(.rewards)
        }

        switch viewModel.status {
        case .undefined:
            skeletonOptions.insert(.status)
        case let .active(index):
            presentActiveStatus(for: index)
        case let .inactive(index):
            presentInactiveStatus(for: index)
        case let .waiting(eraCountdown, nominationEra):
            let remainingTime: TimeInterval? = eraCountdown.map { countdown in
                countdown.timeIntervalTillStart(targetEra: nominationEra + 1)
            }
            presentWaitingStatus(remainingTime: remainingTime)
        case .validatorsNotSelected:
            presentValidatorsAreNotSelectedStatus()
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

    private func presentActiveStatus(for era: EraIndex) {
        statusView.titleView.indicatorColor = R.color.colorGreen()!
        statusView.titleView.titleLabel.textColor = R.color.colorGreen()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusActive(preferredLanguages: locale.rLanguages).uppercased()
        statusView.valueView.detailsLabel.text = R.string.localizable
            .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()
    }

    private func presentInactiveStatus(for era: UInt32) {
        statusView.titleView.indicatorColor = R.color.colorRed()!
        statusView.titleView.titleLabel.textColor = R.color.colorRed()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusInactive(preferredLanguages: locale.rLanguages).uppercased()
        statusView.valueView.detailsLabel.text = R.string.localizable.stakingEraTitle(
            "\(era)",
            preferredLanguages: locale.rLanguages
        ).uppercased()
    }

    private func presentWaitingStatus(remainingTime: TimeInterval?) {
        statusView.titleView.indicatorColor = R.color.colorTransparentText()!
        statusView.titleView.titleLabel.textColor = R.color.colorTransparentText()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingNominatorStatusWaiting(preferredLanguages: locale.rLanguages).uppercased()

        if let remainingTime = remainingTime {
            timer.start(with: remainingTime, runLoop: .main, mode: .common)
        } else {
            statusView.valueView.detailsLabel.text = ""
        }
    }

    private func presentValidatorsAreNotSelectedStatus() {
        statusView.titleView.indicatorColor = R.color.colorOrange()!
        statusView.titleView.titleLabel.textColor = R.color.colorOrange()!

        statusView.titleView.titleLabel.text = R.string.localizable
            .stakingSetValidatorsMessage(preferredLanguages: locale.rLanguages).uppercased()
    }
}

extension NominatorStateView: CountdownTimerDelegate {
    func didStart(with interval: TimeInterval) {
        statusView.valueView.detailsLabel.text = (try? timeFormatter.string(from: interval)) ?? ""
    }

    func didCountdown(remainedInterval: TimeInterval) {
        statusView.valueView.detailsLabel.text = (try? timeFormatter.string(from: remainedInterval)) ?? ""
    }

    func didStop(with _: TimeInterval) {
        statusView.valueView.detailsLabel.text = ""
    }
}
