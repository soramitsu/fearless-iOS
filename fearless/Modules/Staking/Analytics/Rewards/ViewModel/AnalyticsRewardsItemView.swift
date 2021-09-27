typealias AnalyticsRewardsItemView = StakingBalanceUnbondingItemView
typealias AnalyticsRewardsItemViewModel = UnbondingItemViewModel

struct AnalyticsRewardSection {
    let title: String
    let items: [AnalyticsRewardsItem]
}

struct AnalyticsRewardsItem {
    let viewModel: AnalyticsRewardsItemViewModel
    let rawModel: AnalyticsRewardDetailsModel
}
