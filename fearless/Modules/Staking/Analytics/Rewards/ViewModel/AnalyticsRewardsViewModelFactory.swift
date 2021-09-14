import BigInt
import SoraFoundation

final class AnalyticsRewardsViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryRewardItemData>,
    AnalyticsRewardsViewModelFactoryProtocol {
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
        let groupedByDate = data
            .groupedBy(dateComponents: dateComponents, calendar: calendar)
        let sortedRewardsByDate: [(Date, [SubqueryRewardItemData])] = groupedByDate.keys
            .map { (key: Date) in (key, groupedByDate[key]!) }
            .sorted(by: { $0.0 < $1.0 })

        let timestampInterval = period.timestampInterval(startDate: startDate, endDate: endDate, calendar: calendar)
        let chartBarsCount = period.chartBarsCount(startDate: startDate, endDate: endDate, calendar: calendar)
        let formatter = dateFormatter(period: period, for: locale)
        let timestampDistance = timestampInterval.1 - timestampInterval.0

        return (0 ..< chartBarsCount).map { index in
            let indexOfAccumulatedBar = timestampDistance / Int64(chartBarsCount)
            let timestampOfAccumulatedBar: Int64 = timestampInterval.0 + Int64(index) * indexOfAccumulatedBar
            let dateRepresentingAccumulatedBar = Date(timeIntervalSince1970: TimeInterval(timestampOfAccumulatedBar))
            let rewardsByDate = sortedRewardsByDate
                .last(where: { rewardsByDate in
                    let timeIntervalOfAccumulatedBar = rewardsByDate.0.timeIntervalSince(dateRepresentingAccumulatedBar)
                    return timeIntervalOfAccumulatedBar < TimeInterval(indexOfAccumulatedBar)
                })
            return createSelectedChartData(rewardsByDate: rewardsByDate, dateFormatter: formatter, locale: locale)
        }
    }

    private func createSelectedChartData(
        rewardsByDate: (Date, [SubqueryRewardItemData])?,
        dateFormatter: DateFormatter,
        locale: Locale
    ) -> AnalyticsSelectedChartData {
        guard let rewardsByDate = rewardsByDate else {
            return AnalyticsSelectedChartData(
                yValue: 0,
                dateTitle: "",
                sections: []
            )
        }

        let yValue = rewardsByDate.1
            .compactMap { Decimal.fromSubstrateAmount($0.amount, precision: chain.addressType.precision) }
            .reduce(0.0, +)

        return AnalyticsSelectedChartData(
            yValue: yValue,
            dateTitle: dateFormatter.string(from: rewardsByDate.0),
            sections: createSections(rewardsData: rewardsByDate.1, locale: locale)
        )
    }
}

extension SubqueryRewardItemData: AnalyticsViewModelItem {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    static func emptyListDescription(for locale: Locale) -> String {
        R.string.localizable.stakingAnalyticsRewardsEmptyMessage(preferredLanguages: locale.rLanguages)
    }

    var amountInChart: BigUInt {
        amount
    }

    var amountInHistory: BigUInt {
        amount
    }

    var amountSign: FloatingPointSign {
        .plus
    }
}

extension SubqueryRewardItemData: AnalyticsRewardDetailsModel {
    func typeText(locale: Locale) -> String {
        R.string.localizable.stakingRewardDetailsReward(preferredLanguages: locale.rLanguages)
    }
}
