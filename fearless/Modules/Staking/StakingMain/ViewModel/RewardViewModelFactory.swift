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

    func createRewardViewModel(
        reward: Decimal,
        targetReturn: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<RewardViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAsset)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAsset)

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
