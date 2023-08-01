import Foundation
import BigInt
import SoraFoundation
import SSFModels

final class AnalyticsRewardsParachainViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryRewardItemData>,
    AnalyticsRewardsFlowViewModelFactoryProtocol {
    func createViewModel(
        viewModelState: AnalyticsRewardsViewModelState,
        priceData: PriceData?,
        period: AnalyticsPeriod,
        selectedChartIndex: Int?,
        locale: Locale
    ) -> AnalyticsRewardsViewModel? {
        guard let parachainViewModelState = viewModelState as? AnalyticsRewardsParachainViewModelState,
              let subqueryData = parachainViewModelState.subqueryData else {
            return nil
        }

        return createViewModel(
            from: subqueryData,
            priceData: priceData,
            period: period,
            selectedChartIndex: selectedChartIndex,
            hasPendingRewards: false
        ).value(for: locale)
    }

    override func filterHistoryItems(
        _ items: [SubqueryRewardItemData],
        byDateRange dateRange: (Date, Date)
    ) -> [SubqueryRewardItemData] {
        items.filter { item in
            guard item.isReward else { return false }
            let date = Date(timeIntervalSince1970: TimeInterval(item.timestamp))
            return date >= dateRange.0 && date <= dateRange.1
        }
    }

    override func calculateTotalReceivedTokens(
        historyItems: [SubqueryRewardItemData],
        priceData: PriceData?,
        locale: Locale
    ) -> BalanceViewModelProtocol {
        let rewards = historyItems.filter { $0.isReward }
        let amounts = rewards.map(\.amountInChart)
        let totalReceived = amounts
            .compactMap { Decimal.fromSubstrateAmount($0, precision: assetInfo.assetPrecision) }
            .reduce(0.0, +)

        let totalReceivedTokens = balanceViewModelFactory.balanceFromPrice(
            totalReceived,
            priceData: priceData,
            usageCase: .listCrypto
        ).value(for: locale)

        return totalReceivedTokens
    }

    override func getHistoryItemTitle(data _: SubqueryRewardItemData, locale: Locale) -> String {
        R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
    }

    override func selectedChartData(
        _ data: [SubqueryRewardItemData],
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

        return (0 ..< chartBarsCount).map { index in
            let component: DateComponents = {
                switch period {
                case .month, .week:
                    return DateComponents(day: index)
                case .year, .all:
                    return DateComponents(month: index)
                }
            }()
            let date = calendar.date(byAdding: component, to: timestampInterval.0) ?? startDate
            let rewardsByDate = groupedByDate.map { key, value -> (Date, [SubqueryRewardItemData])? in
                if calendar.isDate(date, equalTo: key, toGranularity: dateGranularity) {
                    return (key, value)
                }
                return nil
            }.compactMap { $0 }
            return createSelectedChartData(
                rewardsByDate: rewardsByDate.first,
                defaultDate: date,
                dateFormatter: formatter,
                locale: locale
            )
        }
    }

    private func createSelectedChartData(
        rewardsByDate: (date: Date, items: [SubqueryRewardItemData])?,
        defaultDate: Date,
        dateFormatter: DateFormatter,
        locale: Locale
    ) -> AnalyticsSelectedChartData {
        guard let rewardsByDate = rewardsByDate else {
            return AnalyticsSelectedChartData(
                yValue: 0,
                dateTitle: dateFormatter.string(from: defaultDate),
                sections: []
            )
        }

        let item = rewardsByDate.items
            .compactMap { Decimal.fromSubstrateAmount($0.amount, precision: assetInfo.assetPrecision) }
            .reduce(0.0, +)

        return AnalyticsSelectedChartData(
            yValue: item,
            dateTitle: dateFormatter.string(from: rewardsByDate.date),
            sections: createSections(historyItems: rewardsByDate.items, locale: locale)
        )
    }

    override func calculateChartAmounts(chartDoubles: [Double]) -> [ChartAmount] {
        let minValue = chartDoubles.min() ?? 0.0
        let amounts: [ChartAmount] = chartDoubles.map { value in
            if value < .leastNonzeroMagnitude {
                let minBarHeight: Double = {
                    if minValue < .leastNonzeroMagnitude {
                        return (chartDoubles.max() ?? 0.0) / 50.0
                    }
                    return minValue / 10.0
                }()
                return ChartAmount(value: minBarHeight, selected: false, filled: false)
            }
            return ChartAmount(value: value, selected: false, filled: true)
        }
        return amounts
    }
}
