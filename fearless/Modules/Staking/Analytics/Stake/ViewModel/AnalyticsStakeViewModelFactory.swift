import BigInt
import SoraFoundation

final class AnalyticsStakeViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryStakeChangeData>,
    AnalyticsStakeViewModelFactoryProtocol {
    override func filterHistoryItems(
        _ items: [SubqueryStakeChangeData],
        byDateRange dateRange: (Date, Date)
    ) -> [SubqueryStakeChangeData] {
        var filtered = items.filter { item in
            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
            return date >= dateRange.0 && date <= dateRange.1
        }
        // add last stake change that is out of current dateRange
        if filtered.isEmpty, let last = items.last {
            filtered.append(last)
        }
        return filtered
    }

    override func getHistoryItemTitle(data: SubqueryStakeChangeData, locale: Locale) -> String {
        data.type.title(for: locale)
    }

    override func selectedChartData(
        _ data: [SubqueryStakeChangeData],
        by period: AnalyticsPeriod,
        locale: Locale
    ) -> [AnalyticsSelectedChartData] {
        let formatter = dateFormatter(period: period, for: locale)

        return data.map { stakeChange in
            let amount = Decimal.fromSubstrateAmount(
                stakeChange.amountInChart,
                precision: assetInfo.assetPrecision
            ) ?? 0.0

            let title = formatter.string(from: stakeChange.date)
            let sections = createSections(historyItems: [stakeChange], locale: locale)
            return AnalyticsSelectedChartData(yValue: amount, dateTitle: title, sections: sections)
        }
    }

    override func calculateTotalReceivedTokens(
        historyItems: [SubqueryStakeChangeData],
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let amounts = historyItems.map(\.amountInChart)
        let totalReceived = Decimal.fromSubstrateAmount(
            amounts.last ?? 0,
            precision: assetInfo.assetPrecision
        ) ?? 0

        let totalReceivedTokens = balanceViewModelFactory.balanceFromPrice(
            totalReceived,
            priceData: priceData
        ).value(for: locale)

        return totalReceivedTokens
    }

    override func calculateChartAmounts(chartDoubles: [Double]) -> [ChartAmount] {
        chartDoubles.map { value in
            ChartAmount(value: value, selected: false, filled: true)
        }
    }
}

extension SubqueryStakeChangeData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    static func emptyListDescription(for locale: Locale) -> String {
        R.string.localizable.stakingAnalyticsStakeEmptyMessage(preferredLanguages: locale.rLanguages)
    }

    var amountInChart: BigUInt {
        accumulatedAmount
    }

    var amountInHistory: BigUInt {
        amount
    }

    var amountSign: FloatingPointSign {
        switch type {
        case .bonded, .rewarded:
            return .plus
        case .unbonded, .slashed:
            return .minus
        }
    }
}

extension SubqueryStakeChangeData: AnalyticsRewardDetailsModel {
    func typeText(locale: Locale) -> String {
        type.title(for: locale)
    }
}
