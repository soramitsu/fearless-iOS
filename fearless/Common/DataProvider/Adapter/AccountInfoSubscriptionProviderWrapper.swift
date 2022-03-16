import RobinHood

final class AccountInfoSubscriptionProviderWrapper: WalletLocalStorageSubscriber {
    enum Subscription {
        case usual(provider: AnyDataProvider<DecodedAccountInfo>)
        case orml(provider: AnyDataProvider<DecodedOrmlAccountInfo>)
    }

    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler

    init(factory: WalletLocalSubscriptionFactoryProtocol, handler: WalletLocalSubscriptionHandler) {
        walletLocalSubscriptionFactory = factory
        walletLocalSubscriptionHandler = handler
    }

    func subscribeAccountProvider(for accountId: AccountId, chain: ChainModel) -> Subscription? {
        if chain.isOrml {
            if let provider = subscribeToOrmlAccountInfoProvider(for: accountId, chain: chain) {
                return .orml(provider: provider)
            }
            return nil
        } else {
            if let provider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId) {
                return .usual(provider: provider)
            }
            return nil
        }
    }
}
