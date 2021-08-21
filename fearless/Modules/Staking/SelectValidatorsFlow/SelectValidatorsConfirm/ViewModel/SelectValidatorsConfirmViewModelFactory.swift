import Foundation
import FearlessUtils
import CommonWallet
import SoraFoundation

protocol SelectValidatorsConfirmViewModelFactoryProtocol {
    func createViewModel(
        from state: SelectValidatorsConfirmationModel,
        asset: WalletAsset
    ) throws
        -> LocalizableResource<SelectValidatorsConfirmViewModel>

    func createHints(from duration: StakingDuration) -> LocalizableResource<[TitleIconViewModel]>
}

final class SelectValidatorsConfirmViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var amountFactory = AmountFormatterFactory()

    func createHints(from duration: StakingDuration) -> LocalizableResource<[TitleIconViewModel]> {
        LocalizableResource { locale in
            let eraDurationString = R.string.localizable.commonHoursFormat(
                format: duration.era.hoursFromSeconds,
                preferredLanguages: locale.rLanguages
            )

            let unlockingDurationString = R.string.localizable.commonDaysFormat(
                format: duration.unlocking.daysFromSeconds,
                preferredLanguages: locale.rLanguages
            )

            return [
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintRewardsFormat(
                        eraDurationString,
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconGeneralReward()
                ),
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintUnstakeFormat(
                        unlockingDurationString,
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconUnbond()
                ),
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintNoRewards(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconNoReward()
                ),
                TitleIconViewModel(
                    title: R.string.localizable.stakingHintRedeem(
                        preferredLanguages: locale.rLanguages
                    ),
                    icon: R.image.iconRedeem()
                )
            ]
        }
    }

    func createViewModel(from state: SelectValidatorsConfirmationModel, asset: WalletAsset) throws
        -> LocalizableResource<SelectValidatorsConfirmViewModel> {
        let icon = try iconGenerator.generateFromAddress(state.wallet.address)

        let amountFormatter = amountFactory.createInputFormatter(for: asset)

        let rewardViewModel: RewardDestinationTypeViewModel

        switch state.rewardDestination {
        case .restake:
            rewardViewModel = .restake
        case let .payout(account):
            let payoutIcon = try iconGenerator.generateFromAddress(account.address)

            rewardViewModel = .payout(icon: payoutIcon, title: account.username)
        }

        return LocalizableResource { locale in
            let amount = amountFormatter.value(for: locale).string(from: state.amount as NSNumber)

            return SelectValidatorsConfirmViewModel(
                senderIcon: icon,
                senderName: state.wallet.username,
                amount: amount ?? "",
                rewardDestination: rewardViewModel,
                validatorsCount: state.targets.count,
                maxValidatorCount: state.maxTargets
            )
        }
    }
}
