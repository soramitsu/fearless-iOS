typealias AnalyticsRewardsItemView = StakingBalanceUnbondingItemView
typealias AnalyticsRewardsItemViewModel = UnbondingItemViewModel

struct AnalyticsRewardSection: Equatable {
    let title: String
    let items: [AnalyticsRewardsItem]
}

struct AnalyticsRewardsItem {
    let viewModel: AnalyticsRewardsItemViewModel
    let rawModel: AnalyticsRewardDetailsModel
}

extension AnalyticsRewardsItem: Equatable {
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.viewModel == rhs.viewModel
    }
}
