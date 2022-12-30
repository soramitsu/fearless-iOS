typealias UnbondingItemViewModel = StakingRewardHistoryCellViewModel

struct StakingBalanceViewModel {
    let title: String?
    let widgetViewModel: StakingBalanceWidgetViewModel
    let actionsViewModel: StakingBalanceActionsWidgetViewModel
    let unbondingViewModel: StakingBalanceUnbondingWidgetViewModel
}
