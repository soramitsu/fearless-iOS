import Foundation
@testable import fearless
import SSFModels

class StakingAnalyticsLocalSubscriptionFactoryStub {
    let weaklyAnalytics: [SubqueryRewardItemData]?

    init(weaklyAnalytics: [SubqueryRewardItemData]? = nil) {
        self.weaklyAnalytics = weaklyAnalytics
    }
}

extension StakingAnalyticsLocalSubscriptionFactoryStub: StakingAnalyticsLocalSubscriptionFactoryProtocol {
    func getWeaklyAnalyticsProvider(
        chainAsset: SSFModels.ChainAsset,
        for address: AccountAddress,
        url: URL
    ) -> AnySingleValueProvider<[SubqueryRewardItemData]>? {
        let provider = SingleValueProviderStub(item: weaklyAnalytics)
        return AnySingleValueProvider(provider)
    }
}
