import Foundation
import SoraFoundation
import IrohaCrypto
import Web3
import SoraKeystore
import SSFModels

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
    private var selectedMetaAccount: MetaAccountModel
    private let eventCenter = EventCenter.shared

    init(
        targetAssetInfo: AssetBalanceDisplayInfo,
        formatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory(),
        selectedMetaAccount: MetaAccountModel
    ) {
        self.targetAssetInfo = targetAssetInfo
        self.formatterFactory = formatterFactory
        self.selectedMetaAccount = selectedMetaAccount

        eventCenter.add(observer: self, dispatchIn: .main)
    }

    func createRewardViewModel(
        reward: Decimal,
        targetReturn: Decimal,
        priceData: PriceData?
    ) -> LocalizableResource<RewardViewModelProtocol> {
        let localizableAmountFormatter = formatterFactory.createTokenFormatter(for: targetAssetInfo, usageCase: .detailsCrypto)
        let priceAssetInfo = AssetBalanceDisplayInfo.forCurrency(selectedMetaAccount.selectedCurrency)
        let localizablePriceFormatter = formatterFactory.createTokenFormatter(for: priceAssetInfo, usageCase: .fiat)

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

extension RewardViewModelFactory: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        selectedMetaAccount = event.account
    }
}
