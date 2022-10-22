import Foundation
import FearlessUtils
import CommonWallet
import SoraFoundation

final class SelectValidatorsConfirmViewModelFactory {
    private let iconGenerator: IconGenerating
    private lazy var amountFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    private let chainAsset: ChainAsset

    init(iconGenerator: IconGenerating, chainAsset: ChainAsset) {
        self.iconGenerator = iconGenerator
        self.chainAsset = chainAsset
    }

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

    func createViewModel(from state: SelectValidatorsConfirmRelaychainModel, asset: AssetModel) throws
        -> LocalizableResource<SelectValidatorsConfirmViewModel> {
        let icon = try iconGenerator.generateFromAddress(state.wallet.address)

        let amountFormatter = amountFactory.createInputFormatter(for: asset.displayInfo)

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
                maxValidatorCount: state.maxTargets,
                selectedCollatorViewModel: nil,
                stakeAmountViewModel: self.createStakedAmountViewModel(state.amount)
            )
        }
    }

    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let localizableBalanceFormatter = amountFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo)

        let iconViewModel = chainAsset.assetDisplayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingStakeMoreAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite(),
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(amountTitle: stakedAmountAttributedString, iconViewModel: iconViewModel)
        }
    }
}
