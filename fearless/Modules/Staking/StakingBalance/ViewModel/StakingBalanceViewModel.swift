typealias UnbondingItemViewModel = StakingRewardHistoryCellViewModel

struct StakingBalanceWidgetViewModel {
    let title: String
    let tokenAmountText: String
    let usdAmountText: String
}

struct StakingBalanceViewModel {
    let widgetViewModels: [StakingBalanceWidgetViewModel]
    let unbondings: [UnbondingItemViewModel]
}
