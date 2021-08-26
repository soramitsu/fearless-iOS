import BigInt
import SoraFoundation

protocol AnalyticsViewModelItem: Dated, AnalyticsRewardDetailsModel {
    var timestamp: Int64 { get }
    var amountInHistory: BigUInt { get }
    var amountInChart: BigUInt { get }
    static func emptyListDescription(for locale: Locale) -> String
}

class AnalyticsViewModelFactoryBase<T: AnalyticsViewModelItem> {
    let chain: Chain
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createViewModel(
        from data: [T],
        priceData: PriceData?,
        period: AnalyticsPeriod
    ) -> LocalizableResource<AnalyticsRewardsViewModel> {
        LocalizableResource { [self] locale in
            let timestampInterval = period.timestampInterval

            let rewardItemsWithinLimits = data
                .filter { itemData in
                    itemData.timestamp >= timestampInterval.0 &&
                        itemData.timestamp <= timestampInterval.1
                }

            let groupedByPeriod = self.chartDecimalValues(rewardItemsWithinLimits, by: period)

            let chartDoubles = groupedByPeriod.map { Double(truncating: $0 as NSNumber) }
            let chartData = ChartData(
                amounts: chartDoubles,
                summary: self.createSummary(chartAmounts: groupedByPeriod, priceData: priceData, locale: locale),
                xAxisValues: period.xAxisValues
            )

            let totalReceived = rewardItemsWithinLimits
                .map(\.amount)
                .compactMap { Decimal.fromSubstrateAmount($0, precision: chain.addressType.precision) }
                .reduce(0.0, +)

            let totalReceivedToken = self.balanceViewModelFactory.balanceFromPrice(
                totalReceived,
                priceData: priceData
            ).value(for: locale)

            let dateFormatter = self.periodDateFormatter(period: period, for: locale)
            let startDate = Date(timeIntervalSince1970: TimeInterval(timestampInterval.0))
            let endDate = Date(timeIntervalSince1970: TimeInterval(timestampInterval.1))

            let periodText = dateFormatter.string(from: startDate, to: endDate)
            let summaryViewModel = AnalyticsSummaryRewardViewModel(
                title: periodText,
                tokenAmount: totalReceivedToken.amount,
                usdAmount: totalReceivedToken.price
            )

            let sections = createSections(rewardsData: rewardItemsWithinLimits, locale: locale)

            let viewModel = AnalyticsRewardsViewModel(
                chartData: chartData,
                summaryViewModel: summaryViewModel,
                selectedPeriod: period,
                sections: sections,
                emptyListDescription: T.emptyListDescription(for: locale)
            )
            return viewModel
        }
    }

    private func periodDateFormatter(period: AnalyticsPeriod, for locale: Locale) -> DateIntervalFormatter {
        let dateTemplate: String = {
            switch period {
            case .week:
                return "MMM d-d, yyyy"
            case .month:
                return "MMM, yyyy"
            case .year, .all:
                return "yyyy"
            }
        }()

        let dateFormatter = DateIntervalFormatter()
        dateFormatter.dateTemplate = dateTemplate
        dateFormatter.locale = locale
        return dateFormatter
    }

    private func createViewModelItems(
        rewardsData: [T],
        locale: Locale
    ) -> [AnalyticsRewardsItem] {
        let txFormatter = DateFormatter.txHistory.value(for: locale)

        return rewardsData.compactMap { itemData in
            let title = getHistoryItemTitle(data: itemData, locale: locale)
            let subtitle = R.string.localizable.stakingTitle(preferredLanguages: locale.rLanguages)
            let tokenAmountText = getTokenAmountText(data: itemData, locale: locale)
            let txDate = Date(timeIntervalSince1970: TimeInterval(itemData.timestamp))
            let txTimeText = txFormatter.string(from: txDate)

            let viewModel = AnalyticsRewardsItemViewModel(
                addressOrName: title,
                daysLeftText: .init(string: subtitle),
                tokenAmountText: "+\(tokenAmountText)",
                usdAmountText: txTimeText
            )
            return AnalyticsRewardsItem(viewModel: viewModel, rawModel: itemData)
        }
    }

    private func createSummary(
        chartAmounts: [Decimal],
        priceData: PriceData?,
        locale: Locale
    ) -> [AnalyticsSummaryRewardViewModel] {
        chartAmounts.map { amount in
            let totalBalance = balanceViewModelFactory.balanceFromPrice(
                amount,
                priceData: priceData
            ).value(for: locale)

            return AnalyticsSummaryRewardViewModel(
                title: "TITLE",
                tokenAmount: totalBalance.amount,
                usdAmount: totalBalance.price
            )
        }
    }

    /// Overrinde in subclasses
    func getHistoryItemTitle(data _: T, locale _: Locale) -> String {
        ""
    }

    private func getTokenAmountText(data: T, locale: Locale) -> String {
        guard
            let tokenDecimal = Decimal.fromSubstrateAmount(
                data.amount,
                precision: chain.addressType.precision
            )
        else { return "" }

        let tokenAmountText = balanceViewModelFactory
            .amountFromValue(tokenDecimal)
            .value(for: locale)
        return tokenAmountText
    }

    private func createSections(
        rewardsData: [T],
        locale: Locale
    ) -> [AnalyticsRewardSection] {
        let dateTitleFormatter = DateFormatter()
        dateTitleFormatter.locale = locale
        dateTitleFormatter.dateFormat = "MMM d"

        let groupedByDay = rewardsData
            .groupedBy(dateComponents: [.year, .month, .day])
        let sortedByDay: [(Date, [T])] = groupedByDay.keys
            .map { (key: Date) in
                (key, groupedByDay[key]!)
            }
            .sorted(by: { $0.0 > $1.0 })

        return sortedByDay
            .map { date, rewards in
                let items = createViewModelItems(rewardsData: rewards, locale: locale)
                let title = dateTitleFormatter.string(from: date).uppercased()

                return AnalyticsRewardSection(
                    title: title,
                    items: items
                )
            }
    }

    /// Override
    func chartDecimalValues<T: AnalyticsViewModelItem>(
        _: [T],
        by _: AnalyticsPeriod
    ) -> [Decimal] {
        []
    }
}

protocol Dated {
    var date: Date { get }
}

private extension Array where Element: Dated {
    func groupedBy(dateComponents: Set<Calendar.Component>) -> [Date: [Element]] {
        let initial: [Date: [Element]] = [:]
        let groupedByDateComponents = reduce(into: initial) { acc, cur in
            let components = Calendar.current.dateComponents(dateComponents, from: cur.date)
            let date = Calendar.current.date(from: components)!
            let existing = acc[date] ?? []
            acc[date] = existing + [cur]
        }

        return groupedByDateComponents
    }
}
