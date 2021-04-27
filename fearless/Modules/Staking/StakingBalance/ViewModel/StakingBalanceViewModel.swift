typealias UnbondingItemViewModel = StakingRewardHistoryCellViewModel

struct StakingBalanceViewModel {
    let widgetViewModel: StakingBalanceWidgetViewModel
    let actionsViewModel: StakingBalanceActionsWidgetViewModel
    let unbondings: [UnbondingItemViewModel]
}
