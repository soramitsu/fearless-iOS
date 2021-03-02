import Foundation
import SoraFoundation
import IrohaCrypto

protocol RewardViewModelFactoryProtocol {
    func createMonthlyRewardViewModel(amount: Decimal,
                                      reward: Decimal,
                                      priceData: PriceData?) -> LocalizableResource<RewardViewModelProtocol>

    func createYearlyRewardViewModel(amount: Decimal,
                                     reward: Decimal,
                                     priceData: PriceData?) -> LocalizableResource<RewardViewModelProtocol>
}

final class RewardViewModelFactory: RewardViewModelFactoryProtocol {
    let walletPrimitiveFactory: WalletPrimitiveFactoryProtocol
    let selectedAddressType: SNAddressType

    private lazy var formatterFactory = AmountFormatterFactory()
    private lazy var priceAsset = {
        walletPrimitiveFactory.createPriceAsset()
    }()

    private lazy var targetAsset = {
        walletPrimitiveFactory.createAssetForAddressType(selectedAddressType)
    }()

    init(walletPrimitiveFactory: WalletPrimitiveFactoryProtocol, selectedAddressType: SNAddressType) {
        self.walletPrimitiveFactory = walletPrimitiveFactory
        self.selectedAddressType = selectedAddressType
    }

    func createMonthlyRewardViewModel(amount: Decimal,
                                      reward: Decimal,
                                      priceData: PriceData?) -> LocalizableResource<RewardViewModelProtocol> {

        return createRewardViewModel(amount: amount,
                                     reward: reward,
                                     priceData: priceData,
                                     divisor: 12.0)
    }

    func createYearlyRewardViewModel(amount: Decimal,
                                     reward: Decimal,
                                     priceData: PriceData?) -> LocalizableResource<RewardViewModelProtocol> {

        return createRewardViewModel(amount: amount,
                                     reward: reward,
                                     priceData: priceData)
    }

    func createRewardViewModel(amount: Decimal,
                               reward: Decimal,
                               priceData: PriceData?,
                               divisor: Decimal = 1.0) -> LocalizableResource<RewardViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAsset)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAsset)

        return LocalizableResource { locale in
            let amountFormatter = localizableAmountFormatter.value(for: locale)

            let amountString = amountFormatter.string(from: reward / divisor) ?? ""

            guard let priceData = priceData, let rate = Decimal(string: priceData.price) else {
                return RewardViewModel(amount: amountString, price: nil, increase: nil)
            }

            let targetAmount = rate * amount / divisor

            let priceFormatter = localizablePriceFormatter.value(for: locale)
            let priceString = priceFormatter.string(from: targetAmount) ?? ""

            let percentageFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

            var rewardPercentage: Decimal = 0.0

            if amount > 0 {
                rewardPercentage = reward / (amount * divisor * 100)
            }

            let rewardPercentageString = percentageFormatter.string(from: rewardPercentage as NSNumber)

            return RewardViewModel(amount: amountString,
                                    price: priceString,
                                    increase: rewardPercentageString)
        }
    }
}
