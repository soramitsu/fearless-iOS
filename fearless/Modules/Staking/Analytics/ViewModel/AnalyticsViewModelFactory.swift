import BigInt

protocol AnalyticsViewModelFactoryProtocol {
    func createViewModel(
        from data: [SubscanRewardItemData],
        priceData: PriceData?,
        period: AnalyticsPeriod
    ) -> AnalyticsViewModel
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

    func createViewModel(
        from data: [SubscanRewardItemData],
        priceData: PriceData?,
        period: AnalyticsPeriod
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

        let rate: Decimal = {
            guard let priceData = priceData else { return Decimal(1) }
            return Decimal(string: priceData.price) ?? Decimal(1)
        }()

        let amountsDecimal = filteredByPeriod.map { rewardItem -> Decimal in
            guard
                let amountValue = BigUInt(rewardItem.amount),
                let decimal = Decimal.fromSubstrateAmount(amountValue, precision: chain.addressType.precision)
            else { return 0.0 }
            return decimal
        }
        let chartDoubles = amountsDecimal.map { Double(truncating: $0 as NSNumber) }
        let chartData = ChartData(amounts: chartDoubles)

        let totalReceived = amountsDecimal.reduce(Decimal(0), +)
        let totalReceivedToken = balanceViewModelFactory.balanceFromPrice(totalReceived, priceData: priceData).value(for: .current)
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

        return AnalyticsViewModel(
            chartData: chartData,
            receivedViewModel: receivedViewModel,
            payableViewModel: payableViewModel
        )
    }
}
