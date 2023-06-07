import Foundation
import SoraFoundation
import BigInt
import SSFModels

final class AnalyticsRewardDetailsViewModelFactory: AnalyticsRewardDetailsViewModelFactoryProtocol {
    let chainAsset: ChainAsset
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var txDateFormatter = DateFormatter.txDetails

    init(
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chainAsset = chainAsset
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createViweModel(
        rewardModel: AnalyticsRewardDetailsModel
    ) -> LocalizableResource<AnalyticsRewardDetailsViewModel> {
        LocalizableResource { locale in
            let formatter = self.txDateFormatter.value(for: locale)
            let date = formatter.string(from: rewardModel.date)
            let amount = self.getTokenAmountText(amount: rewardModel.amount, locale: locale)

            return AnalyticsRewardDetailsViewModel(
                eventId: rewardModel.eventId,
                date: date,
                type: rewardModel.typeText(locale: locale),
                amount: amount
            )
        }
    }

    private func getTokenAmountText(amount: BigUInt, locale: Locale) -> String {
        guard
            let tokenDecimal = Decimal.fromSubstrateAmount(
                amount,
                precision: Int16(chainAsset.asset.precision)
            )
        else { return "" }

        let tokenAmountText = balanceViewModelFactory
            .amountFromValue(tokenDecimal, usageCase: .detailsCrypto)
            .value(for: locale)
        return tokenAmountText
    }
}
