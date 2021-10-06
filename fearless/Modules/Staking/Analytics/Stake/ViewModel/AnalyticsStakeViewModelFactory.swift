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
        let dates = data.map(\.date)
        guard let startDate = dates.first, let endDate = dates.last else { return [] }

        let dateComponents: Set<Calendar.Component> = {
            switch period {
            case .month, .week:
                return [.year, .month, .day]
            case .year, .all:
                return [.year, .month]
            }
        }()

        let dateGranularity: Calendar.Component = {
            switch period {
            case .month, .week:
                return .day
            case .year, .all:
                return .month
            }
        }()

        let groupedByDate = data
            .groupedBy(dateComponents: dateComponents, calendar: calendar)

        let timestampInterval = period.dateRangeTillNow(startDate: startDate, endDate: endDate, calendar: calendar)
        let chartBarsCount = period.chartBarsCount(startDate: startDate, endDate: endDate, calendar: calendar)
        let formatter = dateFormatter(period: period, for: locale)

        let stakeChangesSortedByDate = groupedByDate.sorted(by: { lhs, rhs in
            lhs.key < rhs.key
        })

        return (0 ..< chartBarsCount).map { index in
            let component: DateComponents = {
                switch period {
                case .month, .week:
                    return DateComponents(day: index)
                case .year, .all:
                    return DateComponents(month: index)
                }
            }()
            let currentDate = calendar.date(byAdding: component, to: timestampInterval.0) ?? startDate
            let stakeChangesForCurrentDate = groupedByDate
                .compactMap { date, stakeChanges -> (Date, [SubqueryStakeChangeData])? in
                    if calendar.isDate(currentDate, equalTo: date, toGranularity: dateGranularity) {
                        return (date, stakeChanges)
                    }
                    return nil
                }

            let stakeChangesForCurrentOrPreviousDate: (Date, [SubqueryStakeChangeData])? = {
                if let items = stakeChangesForCurrentDate.first {
                    return items
                } else {
                    let stakeChangesForPreviousDate = stakeChangesSortedByDate.last(where: { $0.key < currentDate })
                    return (currentDate, stakeChangesForPreviousDate?.value ?? [])
                }
            }()

            return createSelectedChartData(
                stakeChangesByDate: stakeChangesForCurrentOrPreviousDate,
                selectedDate: currentDate,
                dateFormatter: formatter,
                locale: locale
            )
        }
    }

    private func createSelectedChartData(
        stakeChangesByDate: (Date, [SubqueryStakeChangeData])?,
        selectedDate: Date,
        dateFormatter: DateFormatter,
        locale: Locale
    ) -> AnalyticsSelectedChartData {
        guard let stakeChangesByDate = stakeChangesByDate else {
            return AnalyticsSelectedChartData(
                yValue: 0,
                dateTitle: dateFormatter.string(from: selectedDate),
                sections: []
            )
        }

        let yValue = stakeChangesByDate.1
            .compactMap { Decimal.fromSubstrateAmount($0.accumulatedAmount, precision: chain.addressType.precision) }
            .last ?? 0.0

        return AnalyticsSelectedChartData(
            yValue: yValue,
            dateTitle: dateFormatter.string(from: stakeChangesByDate.0),
            sections: createSections(historyItems: stakeChangesByDate.1, locale: locale)
        )
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
