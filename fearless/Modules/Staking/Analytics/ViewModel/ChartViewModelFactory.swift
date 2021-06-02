import BigInt

protocol AnalyticsViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubscanRewardItemData],
        period: AnalyticsPeriod,
        precision: Int16
    ) -> AnalyticsViewModel
}

final class AnalyticsViewModelFactory: AnalyticsViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubscanRewardItemData],
        period: AnalyticsPeriod,
        precision: Int16
    ) -> AnalyticsViewModel {
        let onlyRewards = data.filter { itemData in
            let change = RewardChange(rawValue: itemData.eventId)
            return change == .reward
        }
        let filteredByPeriod = onlyRewards
            .filter { itemData in
                itemData.timestamp >= period.timestampInterval.0 &&
                    itemData.timestamp <= period.timestampInterval.1
            }
            .sorted(by: { $0.timestamp > $1.timestamp })

        let amounts = filteredByPeriod.map { rewardItem -> Double in
            guard
                let amountValue = BigUInt(rewardItem.amount),
                let decimal = Decimal.fromSubstrateAmount(amountValue, precision: precision)
            else { return 0.0 }
            return Double(truncating: decimal as NSNumber)
        }
        let chartData = ChartData(amounts: amounts)

        let receivedViewModel = AnalyticsSummaryRewardViewModel(
            title: "Received",
            tokenAmount: "0.02931 KSM",
            usdAmount: "$11.72",
            indicatorColor: R.color.colorGray()
        )

        let payableViewModel = AnalyticsSummaryRewardViewModel(
            title: "Payable",
            tokenAmount: "0.00875 KSM",
            usdAmount: "$3.5",
            indicatorColor: R.color.colorAccent()
        )

        return AnalyticsViewModel(
            chartData: chartData,
            receivedViewModel: receivedViewModel,
            payableViewModel: payableViewModel
        )
    }
}
