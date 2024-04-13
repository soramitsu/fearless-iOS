import Foundation
import RobinHood
import SSFModels

protocol StakingAnalyticsLocalStorageSubscriber where Self: AnyObject {
    var stakingAnalyticsLocalSubscriptionFactory: StakingAnalyticsLocalSubscriptionFactoryProtocol { get }

    var stakingAnalyticsLocalSubscriptionHandler: StakingAnalyticsLocalSubscriptionHandler { get }

    func subscribeWeaklyRewardAnalytics(
        chainAsset: ChainAsset,
        for address: AccountAddress,
        url: URL
    ) throws -> AnySingleValueProvider<[SubqueryRewardItemData]>?
}

extension StakingAnalyticsLocalStorageSubscriber {
    func subscribeWeaklyRewardAnalytics(
        chainAsset: ChainAsset,
        for address: AccountAddress,
        url: URL
    ) throws -> AnySingleValueProvider<[SubqueryRewardItemData]>? {
        let provider = try stakingAnalyticsLocalSubscriptionFactory
            .getWeaklyAnalyticsProvider(chainAsset: chainAsset, for: address, url: url)

        let updateClosure = { [weak self] (changes: [DataProviderChange<[SubqueryRewardItemData]>]) in
            let result = changes.reduceToLastChange()
            self?.stakingAnalyticsLocalSubscriptionHandler.handleWeaklyRewardAnalytics(
                result: .success(result),
                address: address,
                url: url
            )
        }

        let failureClosure = { [weak self] (error: Error) in
            self?.stakingAnalyticsLocalSubscriptionHandler.handleWeaklyRewardAnalytics(
                result: .failure(error),
                address: address,
                url: url
            )
            return
        }

        let options = DataProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false
        )

        provider?.addObserver(
            self,
            deliverOn: .main,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )

        return provider
    }
}

extension StakingAnalyticsLocalStorageSubscriber where Self: StakingAnalyticsLocalSubscriptionHandler {
    var stakingAnalyticsLocalSubscriptionHandler: StakingAnalyticsLocalSubscriptionHandler { self }
}
