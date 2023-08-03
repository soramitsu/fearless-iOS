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
        deliveryOn queue: DispatchQueue?
    )
    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?
    )

    func reset()
}

extension AccountInfoSubscriptionAdapterProtocol {
    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue? = .main
    ) {
        subscribe(chainAsset: chainAsset, accountId: accountId, handler: handler, deliveryOn: queue)
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue? = .main
    ) {
        subscribe(chainsAssets: chainsAssets, handler: handler, deliveryOn: queue)
    }
}

final class AccountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapterProtocol {
    // MARK: - handler

    private weak var handler: AccountInfoSubscriptionAdapterHandler?

    // MARK: - WalletLocalStorageSubscriber

    internal var walletLocalSubscriptionFactory: WalletLocalSubscriptionFactoryProtocol

    // MARK: - Private properties

    private var subscriptions: [ChainAssetId: StreamableProvider<AccountInfoStorageWrapper>] = [:]
    private var selectedMetaAccount: MetaAccountModel

    private lazy var substrateWrapper: AccountInfoSubscriptionProviderWrapper = {
        AccountInfoSubscriptionProviderWrapper(factory: walletLocalSubscriptionFactory, handler: self)
    }()

    private lazy var ethereumWrapper: EthereumBalanceSubscription = {
        EthereumBalanceSubscription(
            wallet: selectedMetaAccount,
            accountInfoFetching: EthereumAccountInfoFetching(operationQueue: OperationQueue())
        )
    }()

    private var deliveryQueue: DispatchQueue?
    private let lock = ReaderWriterLock()

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
        subscriptions.values.forEach { subscription in
            subscription.removeObserver(substrateWrapper)
        }

        ethereumWrapper.unsubsribe()
        ethereumWrapper.handler = nil

        subscriptions = [:]
    }

    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?
    ) {
        self.handler = handler
        deliveryQueue = queue

        lock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else { return }
            if chainAsset.chain.isEthereum {
                strongSelf.ethereumWrapper.handler = handler
                strongSelf.ethereumWrapper.subscribe(chainAssets: [chainAsset])
            } else {
                strongSelf.subscriptions[chainAsset.chainAssetId]?.removeObserver(strongSelf.substrateWrapper)
                strongSelf.subscriptions[chainAsset.chainAssetId] = nil

                if let subscription = strongSelf.substrateWrapper.subscribeAccountProvider(for: accountId, chainAsset: chainAsset) {
                    strongSelf.subscriptions[chainAsset.chainAssetId] = subscription
                }
            }
        }
    }

    func subscribe(
        chainsAssets: [ChainAsset],
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn queue: DispatchQueue?
    ) {
        lock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.ethereumWrapper.subscribe(chainAssets: chainsAssets.filter { $0.chain.isEthereum })
            strongSelf.ethereumWrapper.handler = handler

            strongSelf.handler = handler
            strongSelf.deliveryQueue = queue

            chainsAssets.filter { !$0.chain.isEthereum }.forEach { chainAsset in

                strongSelf.subscriptions[chainAsset.chainAssetId]?.removeObserver(strongSelf.substrateWrapper)
                strongSelf.subscriptions[chainAsset.chainAssetId] = nil

                let accountRequest = chainAsset.chain.accountRequest()
                if let accountId = strongSelf.selectedMetaAccount.fetch(for: accountRequest)?.accountId,
                   let subscription = strongSelf.substrateWrapper.subscribeAccountProvider(
                       for: accountId,
                       chainAsset: chainAsset
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
