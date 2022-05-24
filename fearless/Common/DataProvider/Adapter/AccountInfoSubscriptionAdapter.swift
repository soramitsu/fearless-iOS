import Foundation
import RobinHood

protocol AccountInfoSubscriptionAdapterHandler: AnyObject {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )
}

protocol AccountInfoSubscriptionAdapterProtocol: AnyObject {
    func subscribe(chain: ChainModel, accountId: AccountId, handler: AccountInfoSubscriptionAdapterHandler?)
    func subscribe(chains: [ChainModel], handler: AccountInfoSubscriptionAdapterHandler?)

    func reset()
}

class AccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    private weak var handler: AccountInfoSubscriptionAdapterHandler?
    internal var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    private var subscriptions: [AccountInfoSubscriptionProviderWrapper.Subscription] = []
    private var selectedMetaAccount: MetaAccountModel

    private lazy var wrapper: AccountInfoSubscriptionProviderWrapper = {
        AccountInfoSubscriptionProviderWrapper(factory: walletLocalSubscriptionFactory, handler: self)
    }()

    init(
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        self.selectedMetaAccount = selectedMetaAccount
    }

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

    func subscribe(chain: ChainModel, accountId: AccountId, handler: AccountInfoSubscriptionAdapterHandler?) {
        reset()

        self.handler = handler
        if let subscription = wrapper.subscribeAccountProvider(for: accountId, chain: chain) {
            subscriptions.append(subscription)
        }
    }

    func subscribe(chains: [ChainModel], handler: AccountInfoSubscriptionAdapterHandler?) {
        reset()

        self.handler = handler

        chains.forEach { chain in
            if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId,
               let subscription = wrapper.subscribeAccountProvider(for: accountId, chain: chain) {
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
        chainId: ChainModel.Id
    ) {
        handler?.handleAccountInfo(
            result: result,
            accountId: accountId,
            chainId: chainId
        )
    }
}
