import Foundation
import RobinHood
import SSFModels

protocol AccountInfoUpdatingServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class AccountInfoUpdatingService {
    struct SubscriptionInfo {
        let subscriptionId: String
        let accountId: AccountId
        /// Subscriptions are stored by chain-asset key; a chain's removal finds all of its own by this id.
        let chainId: ChainModel.Id
        /// The service that attached the subscription holds it, so only that service can end it.
        let service: WalletRemoteSubscriptionServiceProtocol
    }

    private(set) var selectedMetaAccount: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let substrateRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    private let ethereumRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    private let logger: LoggerProtocol?
    private let eventCenter: EventCenterProtocol
    private var chains: [ChainModel.Id: ChainModel] = [:]

    private var subscribedChains: [ChainAssetKey: SubscriptionInfo] = [:]

    // Created with the service: a lazily created lock can be created twice by two first callers.
    private let readLock = ReaderWriterLock()

    private lazy var chainConnectionVisibilityHelper = {
        ChainConnectionVisibilityHelper()
    }()

    deinit {
        removeAllSubscriptions()
    }

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol,
        ethereumRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol,
        logger: LoggerProtocol?,
        eventCenter: EventCenterProtocol
    ) {
        selectedMetaAccount = selectedAccount
        self.chainRegistry = chainRegistry
        substrateRemoteSubscriptionService = remoteSubscriptionService
        self.ethereumRemoteSubscriptionService = ethereumRemoteSubscriptionService
        self.logger = logger
        self.eventCenter = eventCenter
    }

    private func removeAllSubscriptions() {
        for chainAssetKey in subscribedChains.keys {
            removeSubscription(for: chainAssetKey)
        }
    }

    private func getRemoteSubscriptionService(for chainAsset: ChainAsset) -> WalletRemoteSubscriptionServiceProtocol {
        if chainAsset.chain.isEthereum {
            return ethereumRemoteSubscriptionService
        } else {
            return substrateRemoteSubscriptionService
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case let .insert(newItem):
                if chainRegistry.availableChainIds.or([]).contains(newItem.chainId) {
                    if chainConnectionVisibilityHelper.shouldHaveConnetion(newItem, wallet: selectedMetaAccount) {
                        newItem.chainAssets.forEach {
                            addSubscriptionIfNeeded(for: $0)
                        }
                    }
                    readLock.exclusivelyWrite { [weak self] in
                        guard let self else { return }
                        self.chains[newItem.chainId] = newItem
                    }
                } else {
                    readLock.exclusivelyWrite { [weak self] in
                        guard let self else { return }
                        self.chains[newItem.chainId] = newItem
                    }
                }
            case let .update(chain):
                chain.chainAssets.forEach {
                    addSubscriptionIfNeeded(for: $0)
                }
            case let .delete(deletedIdentifier):
                removeChain(deletedIdentifier)
            }
        }
    }

    private func addSubscriptionIfNeeded(for chainAsset: ChainAsset, closure: RemoteSubscriptionClosure? = nil) {
        Task {
            guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                logger?.error("Couldn't create account for chain \(chainAsset.chain.chainId)")
                return
            }

            guard !chainAsset.chain.isEthereum else {
                return
            }

            let service = getRemoteSubscriptionService(for: chainAsset)
            let maybeSubscriptionId = await service.attachToAccountInfo(
                of: accountId,
                chainAsset: chainAsset,
                queue: nil,
                closure: closure
            )

            if let subsciptionId = maybeSubscriptionId {
                let subscription = SubscriptionInfo(
                    subscriptionId: subsciptionId,
                    accountId: accountId,
                    chainId: chainAsset.chain.chainId,
                    service: service
                )

                setSubscription(subscription, for: chainAsset.uniqueKey(accountId: accountId))
            }
        }
    }

    private func setSubscription(_ subscription: SubscriptionInfo?, for key: String) {
        readLock.exclusivelyWrite { [weak self] in
            self?.subscribedChains[key] = subscription
        }
    }

    private func getSubscription(for key: ChainAssetKey) -> SubscriptionInfo? {
        readLock.concurrentlyRead { subscribedChains[key] }
    }

    private func updateSubscription(for chainAsset: ChainAsset) {
        guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }
        let key = chainAsset.uniqueKey(accountId: accountId)

        guard let subscriptionInfo = getSubscription(for: key) else {
            logger?.error("Expected to update subscription but not found for \(key)")
            return
        }

        subscriptionInfo.service.detachFromAccountInfo(
            for: subscriptionInfo.subscriptionId,
            chainAssetKey: key,
            queue: nil
        ) { [weak self] _ in
            self?.setSubscription(nil, for: key)
            self?.addSubscriptionIfNeeded(for: chainAsset) { result in
                switch result {
                case .success:
                    let event = WalletRemoteSubscriptionWasUpdatedEvent(chainAsset: chainAsset)
                    self?.eventCenter.notify(with: event)
                case let .failure(error):
                    self?.logger?.error("Can't add subscription if nedded error: \(error)")
                }
            }
        }
    }

    /// A deleted chain is forgotten (a wallet change must not attach it again) and every subscription of its assets
    /// ends. A deletion carries the chain id, while subscriptions are stored by chain-asset key.
    private func removeChain(_ chainId: ChainModel.Id) {
        readLock.exclusivelyWrite { [weak self] in
            self?.chains[chainId] = nil
        }

        let keys = readLock.concurrentlyRead {
            subscribedChains.filter { $0.value.chainId == chainId }.map(\.key)
        }

        guard !keys.isEmpty else {
            logger?.error("Expected to remove subscriptions but found none for chain \(chainId)")
            return
        }

        keys.forEach { removeSubscription(for: $0) }
    }

    private func removeSubscription(for key: ChainAssetKey) {
        guard let subscriptionInfo = getSubscription(for: key) else {
            logger?.error("Expected to remove subscription but not found for \(key)")
            return
        }

        setSubscription(nil, for: key)

        subscriptionInfo.service.detachFromAccountInfo(
            for: subscriptionInfo.subscriptionId,
            chainAssetKey: key,
            queue: nil,
            closure: { [weak self] result in
                switch result {
                case .success:
                    self?.logger?.info("removed subscription for \(key)")
                case let .failure(error):
                    self?.logger?.error("Faced with error: \(error) when detach subscription")
                }
            }
        )
    }

    private func subscribeToChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .global()
        ) { [weak self] changes in
            self?.handle(changes: changes)
        }
    }

    private func unsubscribeFromChains() {
        subscribedChains = [:]
        chainRegistry.chainsUnsubscribe(self)
    }
}

extension AccountInfoUpdatingService: AccountInfoUpdatingServiceProtocol {
    func setup() {
        subscribeToChains()

        eventCenter.add(observer: self)
    }

    func throttle() {
        unsubscribeFromChains()
    }

    func update(selectedMetaAccount: MetaAccountModel) {
        removeAllSubscriptions()
        self.selectedMetaAccount = selectedMetaAccount

        chains.values.compactMap { $0.chainAssets }.reduce([], +).forEach {
            addSubscriptionIfNeeded(for: $0)
        }
    }
}

extension AccountInfoUpdatingService: EventVisitorProtocol {
    func processChainsUpdated(event: ChainsUpdatedEvent) {
        event.updatedChains.forEach { chain in
            chain.chainAssets.forEach {
                updateSubscription(for: $0)
            }
        }
    }

    func processRuntimeSnapshorReady(event: RuntimeSnapshotReady) {
        let chainAssets = event.chainModel.chainAssets
        chainAssets.forEach {
            updateSubscription(for: $0)
        }
    }
}
