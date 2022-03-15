import Foundation
import RobinHood

protocol AccountInfoSubscriptionAdapterHandler: AnyObject {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainId: ChainModel.Id
    )
}

protocol AccountInfoSubscriptionAdapterProtocol {
    func subscribe(chain: ChainModel, accountId: AccountId, handler: AccountInfoSubscriptionAdapterHandler?)
    func subscribe(chains: [ChainModel], handler: AccountInfoSubscriptionAdapterHandler?)

    func reset()
}

class AccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    private weak var handler: AccountInfoSubscriptionAdapterHandler?
    internal var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol
    private var subscriptions: [AccountInfoSubscriptionProviderWrapper.Subscription] = []
//    private var accountInfoProviders: [AnyDataProvider<DecodedAccountInfo>]?
//    private var ormlAccountInfoProviders: [AnyDataProvider<DecodedOrmlAccountInfo>]?
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
                provider.removeObserver(self)
            case let .orml(provider):
                provider.removeObserver(self)
            }
        }

//        if let providers = ormlAccountInfoProviders {
//            for provider in providers {
//                provider.removeObserver(self)
//            }
//        }
//
//        if let providers = accountInfoProviders {
//            for provider in providers {
//                provider.removeObserver(self)
//            }
//        }
    }

    func subscribe(chain: ChainModel, accountId: AccountId, handler: AccountInfoSubscriptionAdapterHandler?) {
        reset()

        self.handler = handler

//        var ormlProviders: [AnyDataProvider<DecodedOrmlAccountInfo>] = []
//        var defaultProviders: [AnyDataProvider<DecodedAccountInfo>] = []

        if let subscription = wrapper.subscribeAccountProvider(for: accountId, chain: chain) {
            subscriptions.append(subscription)
        }
//        if chain.chainId.isOrml {
//            if let provider = subscribeToOrmlAccountInfoProvider(for: accountId, chain: chain) {
//                ormlProviders.append(provider)
//            }
//        }
//
//        if !chain.chainId.isOrml {
//            if let provider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId) {
//                defaultProviders.append(provider)
//            }
//        }

//        ormlAccountInfoProviders = ormlProviders
//        accountInfoProviders = defaultProviders
    }

    func subscribe(chains: [ChainModel], handler: AccountInfoSubscriptionAdapterHandler?) {
        reset()

        self.handler = handler

//        var ormlProviders: [AnyDataProvider<DecodedOrmlAccountInfo>] = []
//        var defaultProviders: [AnyDataProvider<DecodedAccountInfo>] = []

        chains.forEach { chain in
            if let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId,
               let subscription = wrapper.subscribeAccountProvider(for: accountId, chain: chain) {
                subscriptions.append(subscription)
            }
        }
//            if chain.chainId.isOrml, let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
//                if let provider = subscribeToOrmlAccountInfoProvider(for: accountId, chain: chain) {
//                    ormlProviders.append(provider)
//                }
//            }
//
//            if !chain.chainId.isOrml, let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId {
//                if let provider = subscribeToAccountInfoProvider(for: accountId, chainId: chain.chainId) {
//                    defaultProviders.append(provider)
//                }
//            }

//        ormlAccountInfoProviders = ormlProviders
//        accountInfoProviders = defaultProviders
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
