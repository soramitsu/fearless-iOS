import Foundation

final class AnalyticsRewardsRelaychainViewModelState {
    var stateListener: AnalyticsRewardsModelStateListener?
    private(set) var subqueryData: [SubqueryRewardItemData]?
    private(set) var stashItem: StashItem?
}

extension AnalyticsRewardsRelaychainViewModelState: AnalyticsRewardsViewModelState {
    var hasPendingRewards: Bool {
        true
    }

    var historyAddress: String? {
        stashItem?.stash
    }

    func setStateListener(_ stateListener: AnalyticsRewardsModelStateListener?) {
        self.stateListener = stateListener
    }
}

extension AnalyticsRewardsRelaychainViewModelState: AnalyticsRewardsRelaychainStrategyOutput {
    func didReceieveSubqueryData(_ subqueryData: [SubqueryRewardItemData]?) {
        self.subqueryData = subqueryData

        stateListener?.provideRewardsViewModel()
    }

    func didReceiveStashItem(_ stashItem: StashItem?) {
        self.stashItem = stashItem
    }

    func didReceiveError(_ error: Error) {
        stateListener?.provideError(error)
    }
}
