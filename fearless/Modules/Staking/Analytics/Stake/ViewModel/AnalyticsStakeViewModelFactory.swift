import BigInt
import SoraFoundation

final class AnalyticsStakeViewModelFactory: AnalyticsViewModelFactoryBase<SubqueryStakeChangeData>,
    AnalyticsStakeViewModelFactoryProtocol {
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
            let sections = createSections(rewardsData: [stakeChange], locale: locale)
            return AnalyticsSelectedChartData(yValue: amount, dateTitle: title, sections: sections)
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
