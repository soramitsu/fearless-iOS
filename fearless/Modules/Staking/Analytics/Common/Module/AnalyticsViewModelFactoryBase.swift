import BigInt
import SoraFoundation

protocol AnalyticsViewModelItem: Dated, AnalyticsRewardDetailsModel {
    var timestamp: Int64 { get }
    var amountInHistory: BigUInt { get }
    var amountInChart: BigUInt { get }
    var amountSign: FloatingPointSign { get }
    static func emptyListDescription(for locale: Locale) -> String
}

struct AnalyticsSelectedChartData {
    let yValue: Decimal
    let dateTitle: String
    let sections: [AnalyticsRewardSection]
}

class AnalyticsViewModelFactoryBase<T: AnalyticsViewModelItem> {
    let chain: Chain
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let calendar: Calendar

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        calendar: Calendar
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
        self.calendar = calendar
    }

    func createViewModel(
        from data: [T],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        selectedChartIndex: Int?
    ) -> LocalizableResource<AnalyticsRewardsViewModel> {
        LocalizableResource { [self] locale in
            let allDates = data.map(\.date)
            let (startDate, endDate) = (allDates.first ?? Date(), allDates.last ?? Date())
            let dateRange = period.dateRangeTillNow(startDate: startDate, endDate: endDate, calendar: calendar)

            let filteredHistoryItems = filterHistoryItems(data, byDateRange: dateRange)
            let groupedByPeriodChartData = self.selectedChartData(filteredHistoryItems, by: period, locale: locale)

            let chartData = createChartData(
                yValues: groupedByPeriodChartData.map(\.yValue),
                dateRange: dateRange,
                period: period,
                selectedChartIndex: selectedChartIndex,
                locale: locale
            )

            let totalReceivedTokens = calculateTotalReceivedTokens(
                historyItems: filteredHistoryItems,
                priceData: priceData,
                locale: locale
            )

            let summaryViewModel: AnalyticsSummaryRewardViewModel = {
                if let index = selectedChartIndex, index < groupedByPeriodChartData.count {
                    return createSummary(
                        selectedChartData: groupedByPeriodChartData[index],
                        priceData: priceData,
                        locale: locale
                    )
                } else {
                    let dateFormatter = dateIntervalFormatter(period: period, for: locale)
                    let periodText = dateFormatter.string(from: dateRange.0, to: dateRange.1)
                    return AnalyticsSummaryRewardViewModel(
                        title: periodText,
                        tokenAmount: totalReceivedTokens.amount,
                        usdAmount: totalReceivedTokens.price
                    )
                }
            }()

            let sections: [AnalyticsRewardSection] = {
                if let index = selectedChartIndex, index < groupedByPeriodChartData.count {
                    return groupedByPeriodChartData[index].sections
                } else {
                    return createSections(historyItems: filteredHistoryItems, locale: locale)
                }
            }()

            return AnalyticsRewardsViewModel(
                chartData: chartData,
                summaryViewModel: summaryViewModel,
                selectedPeriod: period,
                sections: sections,
                emptyListDescription: T.emptyListDescription(for: locale)
            )
        }
    }

    /// Override in subclasses
    func filterHistoryItems(_ items: [T], byDateRange _: (Date, Date)) -> [T] {
        items
    }

    private func createChartData(
        yValues: [Decimal],
        dateRange: (Date, Date),
        period: AnalyticsPeriod,
        selectedChartIndex: Int?,
        locale: Locale
    ) -> ChartData {
        let chartDoubles = yValues
            .map { Double(truncating: $0 as NSNumber) }

        let amounts = calculateChartAmounts(chartDoubles: chartDoubles)

        let bottomYValue = balanceViewModelFactory.amountFromValue(0.0).value(for: locale)
        let averageAmount: Double? = {
            guard !chartDoubles.isEmpty else { return nil }
            return chartDoubles.reduce(0.0, +) / Double(chartDoubles.count)
        }()

        let averageAmountText: String? = {
            guard let averageAmount = averageAmount else { return nil }
            let averageAmountRawText = balanceViewModelFactory
                .amountFromValue(Decimal(averageAmount))
                .value(for: locale)
                .replacingOccurrences(of: " ", with: "\n")
            return R.string.localizable.stakingAnalyticsAvg(
                averageAmountRawText,
                preferredLanguages: locale.rLanguages
            )
        }()

        let selectedChartAmounts: [ChartAmount] = {
            guard let selectedIndex = selectedChartIndex else { return amounts }
            return amounts.enumerated().map { (index, chartAmount) -> ChartAmount in
                if index == selectedIndex {
                    return ChartAmount(value: chartAmount.value, selected: true, filled: true)
                }
                return ChartAmount(value: chartAmount.value, selected: false, filled: false)
            }
        }()

        return ChartData(
            amounts: selectedChartAmounts,
            xAxisValues: period.xAxisValues(dateRange: dateRange, locale: locale),
            bottomYValue: bottomYValue,
            averageAmountValue: averageAmount,
            averageAmountText: averageAmountText
        )
    }

    func calculateChartAmounts(chartDoubles _: [Double]) -> [ChartAmount] {
        []
    }

    /// Override in subclasses
    func calculateTotalReceivedTokens(
        historyItems _: [T],
        priceData _: PriceData?,
        locale _: Locale
    ) -> BalanceViewModelProtocol {
        BalanceViewModel(amount: "", price: nil)
    }

    private func dateIntervalFormatter(period: AnalyticsPeriod, for locale: Locale) -> DateIntervalFormatter {
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

    func dateFormatter(period: AnalyticsPeriod, for locale: Locale) -> DateFormatter {
        let template: String = {
            switch period {
            case .week, .month:
                return "MMM d, yyyy"
            case .year, .all:
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
                tokenAmountText: tokenAmountText,
                usdAmountText: txTimeText
            )
            return AnalyticsRewardsItem(viewModel: viewModel, rawModel: itemData)
        }
    }

    private func createSummary(
        selectedChartData: AnalyticsSelectedChartData,
        priceData: PriceData?,
        locale: Locale
    ) -> AnalyticsSummaryRewardViewModel {
        let totalBalance = balanceViewModelFactory.balanceFromPrice(
            selectedChartData.yValue,
            priceData: priceData
        ).value(for: locale)

        return AnalyticsSummaryRewardViewModel(
            title: selectedChartData.dateTitle,
            tokenAmount: totalBalance.amount,
            usdAmount: totalBalance.price
        )
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
        let sign = data.amountSign == .plus ? "+" : "-"
        return sign + tokenAmountText
    }

    func createSections(
        historyItems: [T],
        locale: Locale
    ) -> [AnalyticsRewardSection] {
        let dateTitleFormatter = DateFormatter()
        dateTitleFormatter.locale = locale
        dateTitleFormatter.dateFormat = "MMM d"

        let groupedByDay = historyItems
            .groupedBy(dateComponents: [.year, .month, .day], calendar: calendar)
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
    func selectedChartData(
        _: [T],
        by _: AnalyticsPeriod,
        locale _: Locale
    ) -> [AnalyticsSelectedChartData] {
        []
    }
}

protocol Dated {
    var date: Date { get }
}

extension Array where Element: Dated {
    func groupedBy(dateComponents: Set<Calendar.Component>, calendar: Calendar) -> [Date: [Element]] {
        let initial: [Date: [Element]] = [:]
        let groupedByDateComponents = reduce(into: initial) { accumulator, element in
            let components = calendar.dateComponents(dateComponents, from: element.date)
            guard let date = calendar.date(from: components) else { return }
            let existing = accumulator[date] ?? []
            accumulator[date] = existing + [element]
        }

        return groupedByDateComponents
    }
}
