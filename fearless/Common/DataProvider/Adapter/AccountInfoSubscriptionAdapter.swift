import Foundation
import RobinHood
import SSFModels

protocol AccountInfoSubscriptionAdapterHandler: AnyObject {
    func handleAccountInfo(
        result: Result<AccountInfo?, Error>,
        accountId: AccountId,
        chainAsset: ChainAsset
    )
}

protocol AccountInfoSubscriptionAdapterProtocol: AnyObject {
    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated: Bool
    )
    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated: Bool
    )
    func reset()
    func unsubscribe(chainAsset: ChainAsset)
    func update(wallet: MetaAccountModel)
}

extension AccountInfoSubscriptionAdapterProtocol {
    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue? = .main,
        notifyJustWhenUpdated: Bool = false
    ) {
        subscribe(
            chainAsset: chainAsset,
            accountId: accountId,
            handler: handler,
            deliveryOn: queue,
            notifyJustWhenUpdated: notifyJustWhenUpdated
        )
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue? = .main,
        notifyJustWhenUpdated: Bool = false
    ) {
        subscribe(
            chainsAssets: chainsAssets,
            handler: handler,
            deliveryOn: queue,
            notifyJustWhenUpdated: notifyJustWhenUpdated
        )
    }
}

final class AccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    // MARK: - handler

    private weak var handler: AccountInfoSubscriptionAdapterHandler?

    // MARK: - WalletLocalStorageSubscriber

    internal var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    // MARK: - Private properties

    private var subscriptions: [ChainAssetId: StreamableProvider<AccountInfoStorageWrapper>] = [:]
    private(set) var wallet: MetaAccountModel

    private lazy var wrapper: AccountInfoSubscriptionProviderWrapper = {
        AccountInfoSubscriptionProviderWrapper(factory: walletLocalSubscriptionFactory, handler: self)
    }()

    private var deliveryQueue: DispatchQueue?
    private var deliveryGeneration = UUID()
    private let lock = ReaderWriterLock()

    // MARK: - Constructor

    init(
        walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol,
        selectedMetaAccount: MetaAccountModel
    ) {
        self.walletLocalSubscriptionFactory = walletLocalSubscriptionFactory
        wallet = selectedMetaAccount
    }

    // MARK: - Public methods

    func reset() {
        lock.exclusivelyWrite { [self] in
            deliveryGeneration = UUID()
            subscriptions.values.forEach { subscription in
                subscription.removeObserver(wrapper)
            }
            subscriptions = [:]
            // Provider callbacks retain the old wrapper weakly. Disconnect it so
            // a delayed callback cannot be rebound to a later subscription.
            wrapper.walletLocalSubscriptionHandler = nil
            wrapper = AccountInfoSubscriptionProviderWrapper(factory: walletLocalSubscriptionFactory, handler: self)
            handler = nil
        }
    }

    func update(wallet: MetaAccountModel) {
        lock.exclusivelyWrite { [weak self] in
            self?.wallet = wallet
        }
    }

    func unsubscribe(chainAsset: ChainAsset) {
        lock.exclusivelyWrite { [weak self] in
            guard let self else {
                return
            }
            let subscription = self.subscriptions[chainAsset.chainAssetId]
            subscription?.removeObserver(self.wrapper)
            self.subscriptions[chainAsset.chainAssetId] = nil
        }
    }

    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated: Bool
    ) {
        lock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.handler = handler
            strongSelf.deliveryQueue = queue

            strongSelf.subscriptions[chainAsset.chainAssetId]?.removeObserver(strongSelf.wrapper)
            strongSelf.subscriptions[chainAsset.chainAssetId] = nil

            if let subscription = strongSelf.wrapper.subscribeAccountProvider(
                for: accountId,
                chainAsset: chainAsset,
                notifyJustWhenUpdated: notifyJustWhenUpdated
            ) {
                strongSelf.subscriptions[chainAsset.chainAssetId] = subscription
            }
        }
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?,
        notifyJustWhenUpdated: Bool
    ) {
        lock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.handler = handler
            strongSelf.deliveryQueue = queue

            chainsAssets.forEach { chainAsset in
                strongSelf.subscriptions[chainAsset.chainAssetId]?.removeObserver(strongSelf.wrapper)
                strongSelf.subscriptions[chainAsset.chainAssetId] = nil

                let accountRequest = chainAsset.chain.accountRequest()
                if let accountId = strongSelf.wallet.fetch(for: accountRequest)?.accountId,
                   let subscription = strongSelf.wrapper.subscribeAccountProvider(
                       for: accountId,
                       chainAsset: chainAsset,
                       notifyJustWhenUpdated: notifyJustWhenUpdated
                   ) {
                    strongSelf.subscriptions[chainAsset.chainAssetId] = subscription
                }
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
        let (target, queue, generation) = lock.concurrentlyRead {
            (handler, deliveryQueue, deliveryGeneration)
        }
        queue?.async { [weak self, weak target] in
            guard let self, self.lock.concurrentlyRead({ self.deliveryGeneration == generation }) else { return }
            target?.handleAccountInfo(
                result: result,
                accountId: accountId,
                chainAsset: chainAsset
            )
        }
    }
}
