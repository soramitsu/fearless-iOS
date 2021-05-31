import BigInt

protocol ChartViewModelProtocol {
    func createViewModel(
        from data: [SubscanRewardItemData],
        period: AnalyticsPeriod,
        precision: Int16
    ) -> ChartData
}

final class ChartViewModel: ChartViewModelProtocol {
    func createViewModel(
        from data: [SubscanRewardItemData],
        period: AnalyticsPeriod,
        precision: Int16
    ) -> ChartData {
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
        return ChartData(amounts: amounts)
    }
}
