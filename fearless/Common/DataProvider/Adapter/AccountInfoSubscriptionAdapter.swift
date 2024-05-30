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
        subscriptions.values.forEach { subscription in
            subscription.removeObserver(wrapper)
        }

        subscriptions = [:]
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
        self.handler = handler
        deliveryQueue = queue

        lock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else { return }

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
        deliveryQueue?.async {
            self.handler?.handleAccountInfo(
                result: result,
                accountId: accountId,
                chainAsset: chainAsset
            )
        }
    }
}
