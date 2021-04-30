struct StakingBalanceWidgetViewModel {
    let title: String
    let itemViewModels: [StakingBalanceWidgetItemViewModel]
}

struct StakingBalanceWidgetItemViewModel {
    let title: String
    let tokenAmountText: String
    let usdAmountText: String?
}
