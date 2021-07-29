import BigInt
import SoraFoundation

protocol AnalyticsViewModelFactoryProtocol {
    func createRewardsViewModel(
        from data: [SubqueryRewardItemData],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        periodDelta: Int
    ) -> LocalizableResource<AnalyticsRewardsViewModel>
}

final class AnalyticsViewModelFactory: AnalyticsViewModelFactoryProtocol {
    private let chain: Chain
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        chain: Chain,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.chain = chain
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    func createRewardsViewModel(
        from data: [SubqueryRewardItemData],
        priceData: PriceData?,
        period: AnalyticsPeriod,
        periodDelta: Int
    ) -> LocalizableResource<AnalyticsRewardsViewModel> {
        LocalizableResource { [self] locale in
            var resultArray = [Decimal](repeating: 0.0, count: period.chartBarsCount)

            let rewardItemsWithinLimits = data
                .filter { $0.isReward }
                .filter { itemData in
                    let timestampInterval = period.timestampInterval(periodDelta: periodDelta)
                    return itemData.timestamp >= timestampInterval.0 &&
                        itemData.timestamp <= timestampInterval.1
                }

            let groupedByPeriod = rewardItemsWithinLimits
                .reduce(resultArray) { array, value in
                    let timestampInterval = period.timestampInterval(periodDelta: periodDelta)
                    let distance = timestampInterval.1 - timestampInterval.0
                    let index = Int(Double(value.timestamp - timestampInterval.0) / Double(distance) * Double(period.chartBarsCount))
                    guard
                        let amountValue = BigUInt(value.amount),
                        let decimal = Decimal.fromSubstrateAmount(
                            amountValue,
                            precision: self.chain.addressType.precision
                        )
                    else { return array }
                    resultArray[index] += decimal
                    return resultArray
                }

            let chartDoubles = groupedByPeriod.map { Double(truncating: $0 as NSNumber) }
            let chartData = ChartData(amounts: chartDoubles, xAxisValues: period.xAxisValues)

            let totalReceived = groupedByPeriod.reduce(Decimal(0), +)
            let totalReceivedToken = self.balanceViewModelFactory.balanceFromPrice(
                totalReceived,
                priceData: priceData
            ).value(for: locale)

            let dateFormatter = self.periodDateFormatter(period: period, for: locale)
            let timestampInterval = period.timestampInterval(periodDelta: periodDelta)
            let startDate = Date(timeIntervalSince1970: TimeInterval(timestampInterval.0))
            let endDate = Date(timeIntervalSince1970: TimeInterval(timestampInterval.1))

            let periodText = dateFormatter.string(from: startDate, to: endDate)
            let summaryViewModel = AnalyticsSummaryRewardViewModel(
                title: periodText,
                tokenAmount: totalReceivedToken.amount,
                usdAmount: totalReceivedToken.price,
                indicatorColor: nil
            )
            let receivedViewModel = AnalyticsSummaryRewardViewModel(
                title: "Received",
                tokenAmount: totalReceivedToken.amount,
                usdAmount: totalReceivedToken.price,
                indicatorColor: R.color.colorGray()
            )

            let payableViewModel = AnalyticsSummaryRewardViewModel(
                title: "Payable",
                tokenAmount: "0.0 KSM",
                usdAmount: nil,
                indicatorColor: R.color.colorAccent()
            )

            let canSelectNextPeriod = data.contains(where: { $0.timestamp > timestampInterval.1 })
            let periodViewModel = AnalyticsPeriodViewModel(
                periods: AnalyticsPeriod.allCases,
                selectedPeriod: period,
                periodTitle: periodText,
                canSelectNextPeriod: canSelectNextPeriod
            )

            let rewardSections = createRewardSections(
                rewardsData: rewardItemsWithinLimits,
                locale: locale
            )

            return AnalyticsRewardsViewModel(
                chartData: chartData,
                summaryViewModel: summaryViewModel,
                receivedViewModel: receivedViewModel,
                payableViewModel: payableViewModel,
                periodViewModel: periodViewModel,
                rewardSections: rewardSections
            )
        }
    }

    private func periodDateFormatter(period: AnalyticsPeriod, for locale: Locale) -> DateIntervalFormatter {
        let dateTemplate: String = {
            switch period {
            case .weekly:
                return "MMM d-d, yyyy"
            case .monthly:
                return "MMM, yyyy"
            case .yearly:
                return "yyyy"
            }
        }()

        let dateFormatter = DateIntervalFormatter()
        dateFormatter.dateTemplate = dateTemplate
        dateFormatter.locale = locale
        return dateFormatter
    }

    private func createRewardSections(
        rewardsData: [SubqueryRewardItemData],
        locale: Locale
    ) -> [AnalyticsRewardSection] {
        let formatter = DateFormatter.txHistory.value(for: locale)
        let dateTitleFormatter = DateFormatter.shortDate.value(for: locale)

        return rewardsData
            .groupedBy(dateComponents: [.day])
            .map { date, rewards in
                let items: [AnalyticsRewardsItemViewModel] = rewards.compactMap { itemData in
                    guard
                        let amountValue = BigUInt(itemData.amount),
                        let tokenDecimal = Decimal.fromSubstrateAmount(
                            amountValue,
                            precision: self.chain.addressType.precision
                        )
                    else { return nil }

                    let tokenAmountText = balanceViewModelFactory
                        .amountFromValue(tokenDecimal)
                        .value(for: locale)

                    let txDate = Date(timeIntervalSince1970: TimeInterval(itemData.timestamp))
                    let txTimeText = formatter.string(from: txDate)

                    return AnalyticsRewardsItemViewModel(
                        addressOrName: "Reward",
                        daysLeftText: .init(string: "Staking"),
                        tokenAmountText: "+\(tokenAmountText)",
                        usdAmountText: txTimeText
                    )
                }

                let title = dateTitleFormatter.string(from: date)

                return AnalyticsRewardSection(
                    title: title,
                    items: items
                )
            }
    }
}

protocol Dated {
    var date: Date { get }
}

extension Array where Element: Dated {
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

extension SubqueryRewardItemData: Dated {
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}
