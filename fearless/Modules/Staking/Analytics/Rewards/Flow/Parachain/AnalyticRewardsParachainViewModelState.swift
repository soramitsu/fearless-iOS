import Foundation

final class AnalyticsRewardsParachainViewModelState {
    var stateListener: AnalyticsRewardsModelStateListener?
    private(set) var subqueryData: [SubqueryRewardItemData]?
    private let chainAsset: ChainAsset
    private let wallet: MetaAccountModel

    init(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        self.chainAsset = chainAsset
        self.wallet = wallet
    }
}

extension AnalyticsRewardsParachainViewModelState: AnalyticsRewardsViewModelState {
    var hasPendingRewards: Bool {
        false
    }

    var historyAddress: String? {
        wallet.fetch(for: chainAsset.chain.accountRequest())?.toAddress()
    }

    func setStateListener(_ stateListener: AnalyticsRewardsModelStateListener?) {
        self.stateListener = stateListener
    }
}

extension AnalyticsRewardsParachainViewModelState: AnalyticsRewardsParachainStrategyOutput {
    func didReceieveSubqueryData(_ subqueryData: [SubqueryRewardItemData]?) {
        // TODO: Remove once subquery will be fixed
        self.subqueryData = subqueryData?.filter { item in
            Decimal.fromSubstrateAmount(
                item.amount,
                precision: Int16(chainAsset.asset.precision)
            ) ?? 0 < 1
        }

        stateListener?.provideRewardsViewModel()
    }

    func didReceiveError(_ error: Error) {
        stateListener?.provideError(error)
    }
}
