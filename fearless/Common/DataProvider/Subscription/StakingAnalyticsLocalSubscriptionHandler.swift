import Foundation

protocol StakingAnalyticsLocalSubscriptionHandler {
    func handleWeaklyRewardAnalytics(
        result: Result<[SubqueryRewardItemData]?, Error>,
        address: AccountAddress,
        url: URL
    )
}

extension StakingAnalyticsLocalSubscriptionHandler {
    func handleWeaklyRewardAnalytics(
        result _: Result<[SubqueryRewardItemData]?, Error>,
        address _: AccountAddress,
        url _: URL
    ) {}
}
