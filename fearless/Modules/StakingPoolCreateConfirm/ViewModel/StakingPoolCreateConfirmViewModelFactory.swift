import Foundation
import SoraFoundation

struct CreatePoolConfirmData {
    let amount: Decimal
    let price: PriceData?
    let currency: Currency
    let rootName: String
    let poolId: String
    let nominatorName: String
    let stateTogglerName: String
}

protocol StakingPoolCreateConfirmViewModelFactoryProtocol {
    func buildViewModel(
        data: CreatePoolConfirmData,
        locale: Locale
    ) -> StakingPoolCreateConfirmViewModel
}

final class StakingPoolCreateConfirmViewModelFactory: StakingPoolCreateConfirmViewModelFactoryProtocol {
    private let chainAsset: ChainAsset
    private let assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol

    init(
        chainAsset: ChainAsset,
        assetBalanceFormatterFactory: AssetBalanceFormatterFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.assetBalanceFormatterFactory = assetBalanceFormatterFactory
    }

    func buildViewModel(
        data: CreatePoolConfirmData,
        locale: Locale
    ) -> StakingPoolCreateConfirmViewModel {
        let displayInfo = AssetBalanceDisplayInfo.forCurrency(data.currency)
        let tokenFormatter = assetBalanceFormatterFactory.createTokenFormatter(for: displayInfo)
        let tokenFormatterValue = tokenFormatter.value(for: locale)

        let amountString = tokenFormatter.value(for: locale).stringFromDecimal(data.amount) ?? ""
        let stakedString = R.string.localizable.stakingPoolCreateCreatingPool(
            amountString,
            preferredLanguages: locale.rLanguages
        )
        let stakedAmountAttributedString = NSMutableAttributedString(string: stakedString)
        stakedAmountAttributedString.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorWhite(),
            range: (stakedString as NSString).range(of: amountString)
        )

        var price: String?
        if
            let priceData = data.price,
            let priceDecimal = Decimal(string: priceData.price) {
            let totalPrice = data.amount * priceDecimal
            price = tokenFormatterValue.stringFromDecimal(totalPrice)
        }

        return StakingPoolCreateConfirmViewModel(
            amount: stakedAmountAttributedString,
            amountString: amountString,
            price: price,
            rootName: data.rootName,
            poolId: "\(data.poolId)",
            nominatorName: data.nominatorName,
            stateTogglerName: data.stateTogglerName
        )
    }
}
