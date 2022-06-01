import Foundation
import RobinHood

protocol AccountInfoSubscriptionAdapterHandler: AnyObject {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    )
}

protocol AccountInfoSubscriptionAdapterProtocol: AnyObject {
    func subscribe(chainAsset: ChainAsset, accountId: AccountId, handler: AccountInfoSubscriptionAdapterHandler?)
    func subscribe(chainsAssets: [ChainAsset], handler: AccountInfoSubscriptionAdapterHandler?)

    func reset()
}

final class AccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    // MARK: - handler

    private weak var handler: AccountInfoSubscriptionAdapterHandler?

    // MARK: - WalletLocalStorageSubscriber

    internal var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    // MARK: - Private properties

    private var subscriptions: [AccountInfoSubscriptionProviderWrapper.Subscription] = []
    private var selectedMetaAccount: MetaAccountModel

    private lazy var wrapper: AccountInfoSubscriptionProviderWrapper = {
        AccountInfoSubscriptionProviderWrapper(factory: walletLocalSubscriptionFactory, handler: self)
    }()

    // MARK: - Constructor

    init(
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.selectedMetaAccount = selectedMetaAccount
    }

    // MARK: - Public methods

    func reset() {
        subscriptions.forEach { subscription in
            switch subscription {
            case let .usual(provider):
                provider.removeObserver(wrapper)
            case let .orml(provider):
                provider.removeObserver(wrapper)
            }
        }

        subscriptions.removeAll()
    }

    func subscribe(chainAsset: ChainAsset, accountId: AccountId, handler: AccountInfoSubscriptionAdapterHandler?) {
        reset()
        self.handler = handler

        if let subscription = wrapper.subscribeAccountProvider(for: accountId, chainAsset: chainAsset) {
            subscriptions.append(subscription)
        }
    }

    func subscribe(chainsAssets: [ChainAsset], handler: AccountInfoSubscriptionAdapterHandler?) {
        reset()
        self.handler = handler

        chainsAssets.forEach { chainAsset in
            if let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId,
               let subscription = wrapper.subscribeAccountProvider(for: accountId, chainAsset: chainAsset) {
                subscriptions.append(subscription)
            }
        }
    }
}

extension AccountInfoSubscriptionAdapter: AnyProviderAutoCleaning {}

extension AccountInfoSubscriptionAdapter: WalletLocalStorageSubscriber, WalletLocalSubscriptionHandler {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    ) {
        handler?.handleAccountInfo(
            result: result,
            accountId: accountId,
            chainAsset: chainAsset
        )
    }
}
