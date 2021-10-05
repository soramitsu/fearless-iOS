import BigInt
import SoraFoundation

final class AnalyticsStakeViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryStakeChangeData>,
    AnalyticsStakeViewModelFactoryProtocol {
    override func filterHistoryItems(
        _ items: [SubqueryStakeChangeData],
        byDateRange dateRange: (Date, Date)
    ) -> [SubqueryStakeChangeData] {
        var filteredItemsByDateRange = items.filter { item in
            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
            return date >= dateRange.0 && date <= dateRange.1
        }

        // add last stake change that is out of current dateRange
        if filteredItemsByDateRange.isEmpty, let last = items.last {
            filteredItemsByDateRange.append(last)
        }

        return sortItemsByEventIdInsideOneBlock(filteredItemsByDateRange)
    }

    private func sortItemsByEventIdInsideOneBlock(
        _ filteredItemsByDateRange: [SubqueryStakeChangeData]
    ) -> [SubqueryStakeChangeData] {
        filteredItemsByDateRange.sorted(by: { lhs, rhs in
            let lhsEventIdComponents = lhs.eventId.split(separator: "-")
            let rhsEventIdComponents = rhs.eventId.split(separator: "-")

            guard
                let lhsBlockNumberString = lhsEventIdComponents.first,
                let lhsBlockNumber = Int(lhsBlockNumberString),
                let rhsBlockNumberString = rhsEventIdComponents.first,
                let rhsBlockNumber = Int(rhsBlockNumberString)
            else { return false }

            if lhsBlockNumber == rhsBlockNumber {
                guard
                    lhsEventIdComponents.count > 1,
                    rhsEventIdComponents.count > 1,
                    let lhsEventIdx = Int(lhsEventIdComponents[1]),
                    let rhsEventIdx = Int(rhsEventIdComponents[1])
                else { return false }

                return lhsEventIdx < rhsEventIdx
            } else {
                return lhsBlockNumber < rhsBlockNumber
            }
        })
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
                precision: chain.addressType.precision
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
        let totalReceived = Decimal.fromSubstrateAmount(amounts.last ?? 0, precision: chain.addressType.precision) ?? 0

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
