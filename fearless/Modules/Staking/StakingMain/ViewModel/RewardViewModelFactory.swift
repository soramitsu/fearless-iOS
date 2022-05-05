import Foundation
import SoraFoundation
import IrohaCrypto
import BigInt
import SoraKeystore

protocol RewardViewModelFactoryProtocol {
    func createRewardViewModel(
        reward: Decimal,
        targetReturn: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<RewardViewModelProtocol>
}

final class RewardViewModelFactory: RewardViewModelFactoryProtocol {
    private let targetAssetInfo: AssetBalanceDisplayInfo
    private let formatterFactory: AssetBalanceFormatterFactoryProtocol
    private let selectedMetaAccount: MetaAccountModel

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        selectedMetaAccount: MetaAccountModel
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.formatterFactory = formatterFactory
        self.selectedMetaAccount = selectedMetaAccount
    }

    func createRewardViewModel(
        reward: Decimal,
        targetReturn: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<RewardViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.stringFromDecimal(reward) ?? ""

            let percentageFormatter = NumberFormatter.percentBase.localizableResource().value(for: locale)

            let rewardPercentageString = percentageFormatter.string(from: targetReturn as NSNumber)

            guard let priceData = priceData, let rate = Decimal(string: priceData.price) else {
                return RewardViewModel(
                    amount: amountString,
                    price: nil,
                    increase: rewardPercentageString
                )
            }

            let priceAmount = rate * reward

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.stringFromDecimal(priceAmount) ?? ""

            return RewardViewModel(
                amount: amountString,
                price: priceString,
                increase: rewardPercentageString
            )
        }
    }
}
