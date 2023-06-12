import Foundation
import SoraFoundation
import Web3
import SSFModels

protocol StakingPoolManagementViewModelFactoryProtocol {
    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<NSAttributedString>
    func buildUnstakeViewModel(
        stakingInfo: StakingPoolMember?,
        activeEra: EraIndex?,
        stakingDuration: StakingDuration?
    ) -> LocalizableResource<String>?
    func buildViewModel(
        stakeInfo: StakingPoolMember?,
        stakingPool: StakingPool?,
        wallet: MetaAccountModel
    ) -> StakingPoolManagementViewModel
    func buildOptionsPickerViewModels(locale: Locale) -> [IconWithTitleViewModel]
}

final class StakingPoolManagementViewModelFactory {
    private let chainAsset: ChainAsset
    private lazy var formatterFactory = AssetBalanceFormatterFactory()

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }
}

extension StakingPoolManagementViewModelFactory: StakingPoolManagementViewModelFactoryProtocol {
    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<NSAttributedString> {
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo, usageCase: .detailsCrypto)

        return LocalizableResource { locale in
            let amountString = localizableBalanceFormatter.value(for: locale).stringFromDecimal(amount) ?? ""
            let stakedString = R.string.localizable.poolStakingTotalStakeAmountTitle(
                amountString,
                preferredLanguages: locale.rLanguages
            )
            let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
            stakedAmountAttributedString.addAttribute(
                NSAttributedString.Key.foregroundColor,
                value: R.color.colorWhite() as Any,
                range: (stakedString as NSString).range(of: amountString)
            )

            return stakedAmountAttributedString
        }
    }

    func buildUnstakeViewModel(
        stakingInfo: StakingPoolMember?,
        activeEra: EraIndex?,
        stakingDuration: StakingDuration?
    ) -> LocalizableResource<String>? {
        guard let stakingInfo = stakingInfo,
              let activeEra = activeEra,
              let stakingDuration = stakingDuration,
              let unbondingEra = stakingInfo.unbondingEras.map({ $0.era }).min(),
              unbondingEra > activeEra else {
            return nil
        }

        let erasLeft = unbondingEra - activeEra
        let secondsLeft = TimeInterval(erasLeft) * stakingDuration.era

        return LocalizableResource { locale in
            secondsLeft.readableValue(locale: locale)
        }
    }

    func buildViewModel(
        stakeInfo: StakingPoolMember?,
        stakingPool _: StakingPool?,
        wallet _: MetaAccountModel
    ) -> StakingPoolManagementViewModel {
        var unstakeButtonEnabled = false

        if let stakeInfo = stakeInfo {
            unstakeButtonEnabled = stakeInfo.points != BigUInt.zero
        }

        return StakingPoolManagementViewModel(
            stakeMoreButtonVisible: stakeInfo?.points != BigUInt.zero,
            unstakeButtonVisible: unstakeButtonEnabled
        )
    }

    func buildOptionsPickerViewModels(locale: Locale) -> [IconWithTitleViewModel] {
        let validatorsOptionViewModel = IconWithTitleViewModel(
            icon: nil,
            title: R.string.localizable
                .stakingValidatorNominators(preferredLanguages: locale.rLanguages)
        )
        let poolInfoOptionViewModel = IconWithTitleViewModel(
            icon: nil,
            title: R.string.localizable
                .poolCommon(preferredLanguages: locale.rLanguages)
        )

        return [validatorsOptionViewModel, poolInfoOptionViewModel]
    }
}
