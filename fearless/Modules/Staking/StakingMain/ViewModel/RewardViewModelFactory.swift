import Foundation
import SoraFoundation
import IrohaCrypto
import BigInt

protocol RewardViewModelFactoryProtocol {
    func createRewardViewModel(
        reward: Decimal,
        targetReturn: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<RewardViewModelProtocol>
}

final class RewardViewModelFactory: RewardViewModelFactoryProtocol {
    let targetAssetInfo: AssetBalanceDisplayInfo
    let priceAssetInfo: AssetBalanceDisplayInfo
    let formatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        priceAssetInfo: AssetBalanceDisplayInfo = AssetBalanceDisplayInfo.usd(),
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.priceAssetInfo = priceAssetInfo
        self.formatterFactory = formatterFactory
    }

    func createRewardViewModel(
        reward: Decimal,
        targetReturn: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<RewardViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo)
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
