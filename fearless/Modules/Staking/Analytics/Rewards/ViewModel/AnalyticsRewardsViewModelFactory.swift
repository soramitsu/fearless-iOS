import BigInt
import SoraFoundation

final class AnalyticsRewardsViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryRewardItemData>,
    AnalyticsRewardsViewModelFactoryProtocol {
    override func getHistoryItemTitle(data _: SubqueryRewardItemData, locale: Locale) -> String {
        R.string.localizable.stakingReward(preferredLanguages: locale.rLanguages)
    }

    override func chartDecimalValues(
        _ data: [SubqueryRewardItemData],
        by period: AnalyticsPeriod,
        locale: Locale
    ) -> [AnalyticsSelectedChartData] {
        let count = period.chartBarsCount()

        let formatter = dateFormatter(period: period, for: locale)

        let resultArray: [AnalyticsSelectedChartData] = .init(
            repeating: AnalyticsSelectedChartData(yValue: 0, dateTitle: "", sections: []),
            count: count
        )

        let groupedByDay = data
            .groupedBy(dateComponents: [.year, .month, .day])
        let sortedByDay: [(Date, [SubqueryRewardItemData])] = groupedByDay.keys
            .map { (key: Date) in
                (key, groupedByDay[key]!)
            }
            .sorted(by: { $0.0 > $1.0 })

        let grouped = data.reduce(into: [[SubqueryRewardItemData]](repeating: [], count: count)) { array, value in
            let timestampInterval = period.timestampInterval
            let distance = timestampInterval.1 - timestampInterval.0
            let index = Int(
                Double(value.timestamp - timestampInterval.0) / Double(distance) * Double(count)
            )
            array[index].append(value)
        }

        return grouped.map { group in
            guard !group.isEmpty else {
                return AnalyticsSelectedChartData(
                    yValue: 0,
                    dateTitle: "",
                    sections: []
                )
            }
            let dateTitle = formatter.string(from: group[0].date)
            let yValue = group.map(\.amount)
                .compactMap { amount in
                    Decimal.fromSubstrateAmount(
                        amount,
                        precision: chain.addressType.precision
                    )
                }
                .reduce(0.0, +)

            return AnalyticsSelectedChartData(
                yValue: yValue,
                dateTitle: dateTitle,
                sections: createSections(rewardsData: group, locale: locale)
            )
        }
//        return data.reduce(into: resultArray) { array, value in
//            guard let decimal = Decimal.fromSubstrateAmount(
//                value.amount,
//                precision: chain.addressType.precision
//            ) else { return }
//
//            let timestampInterval = period.timestampInterval
//            let distance = timestampInterval.1 - timestampInterval.0
//            let index = Int(
//                Double(value.timestamp - timestampInterval.0) / Double(distance) * Double(count)
//            )
//
//            array[index].yValue += decimal
//            array[index].dateTitle = formatter.string(from: value.date)
//            array[index].sections = createSections(rewardsData: [value], locale: locale)
//        }
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

extension SubqueryRewardItemData: AnalyticsRewardDetailsModel {
    func typeText(locale: Locale) -> String {
        R.string.localizable.stakingRewardDetailsReward(preferredLanguages: locale.rLanguages)
    }
}
