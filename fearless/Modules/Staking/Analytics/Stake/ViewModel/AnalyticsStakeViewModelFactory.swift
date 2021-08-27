import BigInt
import SoraFoundation

final class AnalyticsStakeViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryStakeChangeData>,
    AnalyticsStakeViewModelFactoryProtocol {
    override func getHistoryItemTitle(data: SubqueryStakeChangeData, locale: Locale) -> String {
        data.type.title(for: locale)
    }

    override func chartDecimalValues<T: AnalyticsViewModelItem>(
        _ data: [T],
        by _: AnalyticsPeriod
    ) -> [Decimal] {
        data
            .map(\.amountInChart)
            .compactMap { Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision) }
    }
}

extension SubqueryStakeChangeData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    static func emptyListDescription(for _: Locale) -> String {
        "Your stake changes\nwill appear here" // TODO:
    }

    var amountInChart: BigUInt {
        accumulatedAmount
    }

    var amountInHistory: BigUInt {
        amount
    }
}

extension SubqueryStakeChangeData: AnalyticsRewardDetailsModel {
    func typeText(locale: Locale) -> String {
        type.title(for: locale)
    }
}
