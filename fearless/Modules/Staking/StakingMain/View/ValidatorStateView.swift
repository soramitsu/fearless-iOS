import Foundation
import SoraFoundation

class ValidatorStateView: StakingStateView, LocalizableViewProtocol {
    var locale = Locale.current {
        didSet {
            applyLocalization()
            applyViewModel()
        }
    }

    private var localizableViewModel: LocalizableResource<ValidationViewModelProtocol>?

    override init(frame: CGRect) {
        super.init(frame: frame)

        applyLocalization()
    }

    func bind(viewModel: LocalizableResource<ValidationViewModelProtocol>) {
        localizableViewModel = viewModel

        applyViewModel()
    }

    private func applyLocalization() {
        titleLabel.text = R.string.localizable
            .stakingValidatorSummaryTitle(preferredLanguages: locale.rLanguages)
        stakeTitleLabel.text = R.string.localizable
            .stakingMainStakeBalanceStaked(preferredLanguages: locale.rLanguages)
        rewardTitleLabel.text = R.string.localizable
            .stakingTotalRewards_v190(preferredLanguages: locale.rLanguages)
    }

    private func applyViewModel() {
        guard let viewModel = localizableViewModel?.value(for: locale) else {
            return
        }

        stakeAmountView.valueTop.text = viewModel.totalStakedAmount
        stakeAmountView.valueBottom.text = viewModel.totalStakedPrice
        rewardAmountView.valueTop.text = viewModel.totalRewardAmount
        rewardAmountView.valueBottom.text = viewModel.totalRewardPrice

        if case .undefined = viewModel.status {
            toggleStatus(false)
        } else {
            toggleStatus(true)
        }

        var skeletonOptions: SkeletonOptions = []

        if viewModel.totalStakedAmount.isEmpty {
            skeletonOptions.insert(.stake)
        }

        if viewModel.totalRewardAmount.isEmpty {
            skeletonOptions.insert(.rewards)
        }

        switch viewModel.status {
        case .undefined:
            skeletonOptions.insert(.status)
        case let .active(era):
            presentActiveStatus(for: era)
        case let .inactive(era):
            presentInactiveStatus(for: era)
        }

        if !skeletonOptions.isEmpty, viewModel.hasPrice {
            skeletonOptions.insert(.price)
        }

        updateSkeletonIfNeeded(for: skeletonOptions)
    }

    private func toggleStatus(_ shouldShow: Bool) {
        statusView.isHidden = !shouldShow
        statusButton.isUserInteractionEnabled = shouldShow
    }

    private func presentActiveStatus(for era: UInt32) {
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
        statusView.valueView.detailsLabel.text = R.string.localizable
            .stakingEraTitle("\(era)", preferredLanguages: locale.rLanguages).uppercased()
    }
}
