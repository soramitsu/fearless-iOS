import Foundation
import SoraFoundation
import BigInt

protocol StakingPoolManagementViewModelFactoryProtocol {
    func createStakedAmountViewModel(
        _ amount: Decimal
    ) -> LocalizableResource<NSAttributedString>
    func buildUnstakeViewModel(
        unstakePeriod: TimeInterval?
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
        let localizableBalanceFormatter = formatterFactory.createTokenFormatter(for: chainAsset.assetDisplayInfo)

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
        unstakePeriod: TimeInterval?
    ) -> LocalizableResource<String>? {
        guard let unstakePeriod = unstakePeriod else {
            return nil
        }

        return unstakePeriod.localizedReadableValue()
    }

    func buildViewModel(
        stakeInfo: StakingPoolMember?,
        stakingPool: StakingPool?,
        wallet: MetaAccountModel
    ) -> StakingPoolManagementViewModel {
        var unstakeButtonEnabled = false

        if let stakeInfo = stakeInfo, let stakingPool = stakingPool {
            let userIsPoolOwner = stakingPool.info.roles.root == wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId

            unstakeButtonEnabled = stakeInfo.points != BigUInt.zero && !userIsPoolOwner
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
