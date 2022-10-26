import Foundation
import FearlessUtils
import SoraFoundation

final class SelectValidatorsConfirmParachainViewModelFactory {
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

extension SelectValidatorsConfirmParachainViewModelFactory: SelectValidatorsConfirmViewModelFactoryProtocol {
    func buildAssetBalanceViewModel(viewModelState: SelectValidatorsConfirmViewModelState, priceData: PriceData?, balance: Decimal?) -> LocalizableResource<AssetBalanceViewModelProtocol>? {
        guard let viewModelState = viewModelState as? SelectValidatorsConfirmParachainViewModelState,
              let state = viewModelState.confirmationModel else {
            return nil
        }

        return balanceViewModelFactory.createAssetBalanceViewModel(
            state.amount,
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

        let amountFormatter = amountFactory.createTokenFormatter(for: asset.displayInfo)

        let selectedCollatorViewModel = SelectedValidatorViewModel(
            name: state.target.identity?.name,
            address: state.target.address,
            icon: try? iconGenerator.generateFromAddress(state.target.address)
        )

        return LocalizableResource { [weak self] locale in
            let amount = amountFormatter.value(for: locale).stringFromDecimal(state.amount)
            let amountViewModel = self?.balanceViewModelFactory.balanceFromPrice(
                state.amount,
                priceData: viewModelState.priceData
            ).value(for: locale)

            return SelectValidatorsConfirmViewModel(
                senderAddress: state.wallet.address,
                senderName: state.wallet.username,
                amount: amountViewModel,
                rewardDestination: nil,
                validatorsCount: nil,
                maxValidatorCount: nil,
                selectedCollatorViewModel: selectedCollatorViewModel,
                stakeAmountViewModel: self?.createStakedAmountViewModel(state.amount),
                poolName: nil
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

    private func createStakedAmountViewModel(
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
                value: R.color.colorWhite() as Any,
                range: (stakedString as NSString).range(of: amountString)
            )

            return StakeAmountViewModel(amountTitle: stakedAmountAttributedString, iconViewModel: iconViewModel)
        }
    }
}
