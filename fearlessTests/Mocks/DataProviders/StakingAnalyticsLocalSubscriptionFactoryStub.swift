import Foundation
@testable import fearless

class StakingAnalyticsLocalSubscriptionFactoryStub {
    let weaklyAnalytics: [SubqueryRewardItemData]?

    init(weaklyAnalytics: [SubqueryRewardItemData]? = nil) {
        self.weaklyAnalytics = weaklyAnalytics
    }
}

extension StakingAnalyticsLocalSubscriptionFactoryStub: StakingAnalyticsLocalSubscriptionFactoryProtocol {
    func getWeaklyAnalyticsProvider(
        for address: AccountAddress,
        url: URL
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]> {
        let provider = SingleValueProviderStub(item: weaklyAnalytics)
        return AnySingleValueProvider(provider)
    }
}
