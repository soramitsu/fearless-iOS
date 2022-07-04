import RobinHood

final class AccountInfoSubscriptionProviderWrapper: WalletLocalStorageSubscriber {
    enum Subscription {
        case usual(provider: AnyDataProvider<DecodedAccountInfo>)
        case orml(provider: AnyDataProvider<DecodedOrmlAccountInfo>)
    }

    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    weak var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler?

    init(factory: WalletLocalSubscriptionFactoryProtocol, handler: WalletLocalSubscriptionHandler) {
        walletLocalSubscriptionFactory = factory
        walletLocalSubscriptionHandler = handler
    }

    func subscribeAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset
    ) -> Subscription? {
        var subscription: Subscription?

        switch chainAsset.chainAssetType {
        case .normal:
            if let provider = subscribeToAccountInfoProvider(for: accountId, chainAsset: chainAsset) {
                subscription = .usual(provider: provider)
            }
        case
            .ormlChain,
            .ormlAsset,
            .foreignAsset,
            .stableAssetPoolToken,
            .liquidCroadloan,
            .vToken,
            .vsToken,
            .stable:
            if let provider = subscribeToOrmlAccountInfoProvider(for: accountId, chainAsset: chainAsset) {
                subscription = .orml(provider: provider)
            }
        }

        return subscription
    }
}
