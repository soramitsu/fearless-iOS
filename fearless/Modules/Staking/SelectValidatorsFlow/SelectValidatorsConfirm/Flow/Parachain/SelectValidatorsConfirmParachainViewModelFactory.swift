import Foundation
import FearlessUtils
import SoraFoundation

final class SelectValidatorsConfirmParachainViewModelFactory {
    init(balanceViewModelFactory: BalanceViewModelFactoryProtocol, iconGenerator: IconGenerating) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
    }

    private var iconGenerator: IconGenerating
    private lazy var amountFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
}

extension SelectValidatorsConfirmParachainViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol {
    func buildAssetBalanceViewModel(viewModelState: SelectValidatorsConfirmViewModelState, priceData: PriceData?, balance: Decimal?) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let viewModelState = viewModelState as? SelectValidatorsConfirmParachainViewModelState,
              let state = viewModelState.confirmationModel else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            viewModelState.confirmationModel?.amount ?? 0,
            balance: balance,
            priceData: priceData
        )
    }

    func buildHintsViewModel(viewModelState: SelectValidatorsConfirmViewModelState) -> LocalizableResource<[TitleIconViewModel]>? {
        guard let viewModelState = viewModelState as? SelectValidatorsConfirmParachainViewModelState,
              let networkStakingInfo = viewModelState.networkStakingInfo,
              case let .parachain(baseInfo, parachainInfo) = networkStakingInfo else {
            return nil
        }

        return LocalizableResource { locale in
            let eraDurationString = R.string.localizable.commonHoursFormat(
                format: Int(parachainInfo.rewardPaymentDelay),
                preferredLanguages: locale.rLanguages
            )

            let unlockingDurationString = R.string.localizable.commonDaysFormat(
                format: Int(baseInfo.lockUpPeriod),
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
        guard let viewModelState = viewModelState as? SelectValidatorsConfirmParachainViewModelState,
              let state = viewModelState.confirmationModel else {
            return nil
        }

        let icon = try? iconGenerator.generateFromAddress(state.wallet.address)

        let amountFormatter = amountFactory.createInputFormatter(for: asset.displayInfo)

        let selectedCollatorViewModel = SelectedValidatorViewModel(
            name: state.target.identity?.name,
            address: state.target.address
        )

        return LocalizableResource { locale in
            let amount = amountFormatter.value(for: locale).string(from: state.amount as NSNumber)

            return SelectValidatorsConfirmViewModel(
                senderIcon: icon,
                senderName: state.wallet.username,
                amount: amount ?? "",
                rewardDestination: nil,
                validatorsCount: nil,
                maxValidatorCount: nil,
                selectedCollatorViewModel: selectedCollatorViewModel
            )
        }
    }

    func buildFeeViewModel(
        viewModelState: SelectValidatorsConfirmViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<BalanceViewModelProtocol>? {
        guard let viewModelState = viewModelState as? SelectValidatorsConfirmParachainViewModelState,
              let fee = viewModelState.fee else {
            return nil
        }

        return balanceViewModelFactory.balanceFromPrice(fee, priceData: priceData)
    }
}
