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

            let groupedByPeriod = data
                .filter { $0.isReward }
                .filter { itemData in
                    let timestampInterval = period.timestampInterval(periodDelta: periodDelta)
                    return itemData.timestamp >= timestampInterval.0 &&
                        itemData.timestamp <= timestampInterval.1
                }
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

            let dateFormatter = self.weekDateFormatter(for: locale)
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

            let canSelectPreviousPeriod = data.contains(where: { $0.timestamp < timestampInterval.0 })
            let canSelectNextPeriod = data.contains(where: { $0.timestamp > timestampInterval.1 })

            return AnalyticsRewardsViewModel(
                chartData: chartData,
                summaryViewModel: summaryViewModel,
                receivedViewModel: receivedViewModel,
                payableViewModel: payableViewModel,
                periods: AnalyticsPeriod.allCases,
                selectedPeriod: period,
                periodTitle: periodText,
                canSelectPreviousPeriod: canSelectPreviousPeriod,
                canSelectNextPeriod: canSelectNextPeriod
            )
        }
    }

    private func weekDateFormatter(for locale: Locale) -> DateIntervalFormatter {
        let dateFormatter = DateIntervalFormatter()
        dateFormatter.dateTemplate = "MMM d-d, yyyy"
        dateFormatter.locale = locale
        return dateFormatter
    }
}
