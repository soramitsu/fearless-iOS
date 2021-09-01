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

            let groupedByPeriodTuple = self.chartDecimalValues(rewardItemsWithinLimits, by: period, locale: locale)
            let dates = rewardItemsWithinLimits.map(\.date)
            let groupedByPeriod = groupedByPeriodTuple.map(\.0)
            let chartDoubles = groupedByPeriod
                .map { Double(truncating: $0 as NSNumber) }

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

            let bottomYValue = self.balanceViewModelFactory.amountFromValue(0.0).value(for: locale)
            let averageAmount = chartDoubles.reduce(0.0, +) / Double(groupedByPeriod.count)
            let averageAmountRawText = self.balanceViewModelFactory.amountFromValue(Decimal(averageAmount)).value(for: locale)
            let averageAmountText = averageAmountRawText.replacingOccurrences(of: " ", with: "\n") + " avg."
            let chartData = ChartData(
                amounts: amounts,
                summary: self.createSummary(chartAmounts: groupedByPeriodTuple, priceData: priceData, locale: locale),
                xAxisValues: period.xAxisValues(dates: dates),
                bottomYValue: bottomYValue,
                averageAmountValue: averageAmount,
                averageAmountText: averageAmountText
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
            let startDate = data.first?.date ?? Date()
            let endDate = data.last?.date ?? Date()

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
            case .year:
                return "yyyy"
            }
        }()

        let dateFormatter = DateIntervalFormatter()
        dateFormatter.dateTemplate = dateTemplate
        dateFormatter.locale = locale
        return dateFormatter
    }

    func dateFormatter(period: AnalyticsPeriod, for locale: Locale) -> DateFormatter {
        let template: String = {
            switch period {
            case .week, .month:
                return "MMM d, yyyy"
            case .year:
                return "MMMM yyyy"
            }
        }()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = template
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
        chartAmounts: [(Decimal, String)],
        priceData: PriceData?,
        locale: Locale
    ) -> [AnalyticsSummaryRewardViewModel] {
        chartAmounts.map { amount, title in
            let totalBalance = balanceViewModelFactory.balanceFromPrice(
                amount,
                priceData: priceData
            ).value(for: locale)

            return AnalyticsSummaryRewardViewModel(
                title: title,
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
        by _: AnalyticsPeriod,
        locale _: Locale
    ) -> [(Decimal, String)] {
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
