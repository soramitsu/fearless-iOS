import RobinHood
import SSFModels

final class AccountInfoSubscriptionProviderWrapper: WalletLocalStorageSubscriber {
    var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    weak var walletLocalSubscriptionHandler: WalletLocalSubscriptionHandler?

    init(factory: WalletLocalSubscriptionFactoryProtocol, handler: WalletLocalSubscriptionHandler) {
        walletLocalSubscriptionFactory = factory
        walletLocalSubscriptionHandler = handler
    }

    func subscribeAccountProvider(
        for accountId: AccountId,
        chainAsset: ChainAsset,
        notifyJustWhenUpdated: Bool
    ) -> StreamableProvider<AccountInfoStorageWrapper>? {
        subscribeToAccountInfoProvider(
            for: accountId,
            chainAsset: chainAsset,
            notifyJustWhenUpdated: notifyJustWhenUpdated
        )
    }
}
