import BigInt
import SoraFoundation

final class AnalyticsRewardsViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryRewardItemData>,
    AnalyticsRewardsViewModelFactoryProtocol {
    override func getHistoryItemTitle(data _: SubqueryRewardItemData, locale: Locale) -> String {
        R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
    }

    override func getTokenAmountText(data: SubqueryRewardItemData, locale: Locale) -> String {
        guard
            let tokenDecimal = Decimal.fromSubstrateAmount(
                data.amount,
                precision: chain.addressType.precision
            )
        else { return "" }

        let tokenAmountText = balanceViewModelFactory
            .amountFromValue(tokenDecimal)
            .value(for: locale)
        return "+\(tokenAmountText)"
    }
}

extension SubqueryRewardItemData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
