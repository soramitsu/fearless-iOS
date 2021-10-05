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
        guard filteredItemsByDateRange.count >= 2 else {
            return filteredItemsByDateRange
        }

        var itemsSortedByEventIdInsideOneBlock = [SubqueryStakeChangeData]()
        var lastTimestamp = filteredItemsByDateRange[0].timestamp
        var index = 1
        repeat {
            let currentItem = filteredItemsByDateRange[index]
            if currentItem.timestamp == lastTimestamp {
                let elementsWithEqualTimestamp = filteredItemsByDateRange
                    .filter { $0.timestamp == lastTimestamp }
                let sortedByEventId = elementsWithEqualTimestamp.sorted(by: { lhs, rhs in
                    // `eventId` property stores "blockNumber-evendIdx"
                    // so we parse eventIdx after "-" char
                    guard
                        let lhsIdx = lhs.eventId.lastIndex(of: "-"),
                        let rhsIdx = rhs.eventId.lastIndex(of: "-") else {
                        return false
                    }
                    // got "-\(eventIdx)", then revert to get positive number
                    let leftEventIdx = -(Int(lhs.eventId.suffix(from: lhsIdx)) ?? 0)
                    let rightEventIdx = -(Int(rhs.eventId.suffix(from: rhsIdx)) ?? 0)
                    return leftEventIdx < rightEventIdx
                })
                // at previous iteration `else` we append currentItem, update lastTimestamp
                // and in current branch `if` we found all items with equal lastTimestamp
                // so we need to remove duplicate (last element)
                itemsSortedByEventIdInsideOneBlock = itemsSortedByEventIdInsideOneBlock.dropLast()
                itemsSortedByEventIdInsideOneBlock.append(contentsOf: sortedByEventId)
                index += elementsWithEqualTimestamp.count
            } else {
                itemsSortedByEventIdInsideOneBlock.append(currentItem)
                index += 1
            }
            lastTimestamp = currentItem.timestamp
        } while index < filteredItemsByDateRange.count

        return itemsSortedByEventIdInsideOneBlock
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
