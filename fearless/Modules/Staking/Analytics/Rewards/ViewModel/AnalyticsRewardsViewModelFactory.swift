import BigInt
import SoraFoundation

final class AnalyticsRewardsViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryRewardItemData>,
    AnalyticsRewardsViewModelFactoryProtocol {
    override func getHistoryItemTitle(data _: SubqueryRewardItemData, locale: Locale) -> String {
        R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
    }

    override func chartDecimalValues<T: AnalyticsViewModelItem>(
        _ data: [T],
        by period: AnalyticsPeriod
    ) -> [Decimal] {
        let count = period.chartBarsCount()
        return data.reduce(into: [Decimal](repeating: 0.0, count: count)) { array, value in
            guard let decimal = Decimal.fromSubstrateAmount(
                value.amount,
                precision: chain.addressType.precision
            ) else { return }

            let timestampInterval = period.timestampInterval
            let distance = timestampInterval.1 - timestampInterval.0
            let index = Int(
                Double(value.timestamp - timestampInterval.0) / Double(distance) * Double(count)
            )
            array[index] += decimal
        }
    }
}

extension SubqueryRewardItemData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    static func emptyListDescription(for _: Locale) -> String {
        "Your rewards\nwill appear here" // TODO:
    }

    var amountInChart: BigUInt {
        amount
    }

    var amountInHistory: BigUInt {
        amount
    }
}

extension SubqueryRewardItemData: AnalyticsRewardDetailsModel {}
