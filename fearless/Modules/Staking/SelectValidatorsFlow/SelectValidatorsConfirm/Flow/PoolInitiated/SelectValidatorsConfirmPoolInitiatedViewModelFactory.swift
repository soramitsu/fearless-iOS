import Foundation
import FearlessUtils
import SoraFoundation

// swiftlint:disable type_name
final class SelectValidatorsConfirmPoolInitiatedViewModelFactory {
    private let iconGenerator: IconGenerating
    private lazy var amountFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating,
        chainAsset: ChainAsset
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
        self.chainAsset = chainAsset
    }
}

extension SelectValidatorsConfirmPoolInitiatedViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol {
    func buildAssetBalanceViewModel(viewModelState: SelectValidatorsConfirmViewModelState, priceData: PriceData?, balance: Decimal?) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard
            let viewModelState = viewModelState as? SelectValidatorsConfirmPoolInitiatedViewModelState
        else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState.confirmationModel?.amount ?? 0,
            balance: balance,
            priceData: priceData
        )
    }

    func buildHintsViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState
    ) -> LocalizableResource<[TitleIconViewModel]>? {
        guard
            let viewModelState = viewModelState as? SelectValidatorsConfirmPoolInitiatedViewModelState,
            let duration = viewModelState.stakingDuration
        else {
            return nil
        }

        return LocalizableResource { locale in
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

    func buildViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState,
        asset: AssetModel
    ) throws -> LocalizableResource<SelectValidatorsConfirmViewModel>? {
        guard
            let viewModelState = viewModelState as? SelectValidatorsConfirmPoolInitiatedViewModelState,
            let state = viewModelState.confirmationModel
        else {
            return nil
        }

        let icon = try? iconGenerator.generateFromAddress(state.wallet.address)

        let amountFormatter = amountFactory.createInputFormatter(for: asset.displayInfo)

        let rewardViewModel: RewardDestinationTypeViewModel

        switch state.rewardDestination {
        case .restake:
            rewardViewModel = .restake
        case let .payout(account):
            let payoutIcon = try? iconGenerator.generateFromAddress(account.address)

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
                stakeAmountViewModel: self.createStakedAmountViewModel(state.amount),
                poolName: ""
            )
        }
    }

    func buildFeeViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard
            let viewModelState = viewModelState as? SelectValidatorsConfirmPoolInitiatedViewModelState,
            let fee = viewModelState.fee
        else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
    }

    private func createStakedAmountViewModel(
        _: Decimal
    ) -> LocalizableResource<StakeAmountViewModel>? {
        let iconViewModel = chainAsset.assetDisplayInfo.icon.map { RemoteImageViewModel(url: $0) }

        return LocalizableResource { locale in
            let stakedString = R.string.localizable.stakingSelectValidatorsConfirmTitle(
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorGray(),
                range: (stakedString as NSString).range(of: stakedString)
            )

            return StakeAmountViewModel(amountTitle: stakedAmountAttributedString, iconViewModel: iconViewModel)
        }
    }
}
