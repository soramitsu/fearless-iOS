import Foundation
import RobinHood

protocol AccountInfoUpdatingServiceProtocol: ApplicationServiceProtocol {
    func update(selectedMetaAccount: MetaAccountModel)
}

final class AccountInfoUpdatingService {
    struct SubscriptionInfo {
        let subscriptionId: UUID
        let accountId: AccountId
    }

    private(set) var selectedMetaAccount: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    private let logger: LoggerProtocol?
    private let eventCenter: EventCenterProtocol
    private var chains: [ChainModel.Id: ChainModel] = [:]

    private var subscribedChains: [ChainAssetKey: SubscriptionInfo] = [:]

    private let mutex = NSLock()
    private lazy var readLock = ReaderWriterLock()

    deinit {
        removeAllSubscriptions()
    }

    init(
        selectedAccount: MetaAccountModel,
        chainRegistry: ChainRegistryProtocol,
        remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol,
        logger: LoggerProtocol?,
        eventCenter: EventCenterProtocol
    ) {
        selectedMetaAccount = selectedAccount
        self.chainRegistry = chainRegistry
        self.remoteSubscriptionService = remoteSubscriptionService
        self.logger = logger
        self.eventCenter = eventCenter
    }

    private func removeAllSubscriptions() {
        for chainAssetKey in subscribedChains.keys {
            removeSubscription(for: chainAssetKey)
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        for change in changes {
            switch change {
            case let .insert(newItem):
                if chainRegistry.availableChainIds.or([]).contains(newItem.chainId) {
                    newItem.chainAssets.forEach {
                        addSubscriptionIfNeeded(for: $0)
                    }
                } else {
                    chains[newItem.chainId] = newItem
                }
            case .update:
                break
            case let .delete(deletedIdentifier):
                removeSubscription(for: deletedIdentifier)
            }
        }
    }

    private func addSubscriptionIfNeeded(for chainAsset: ChainAsset, closure: RemoteSubscriptionClosure? = nil) {
        guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            logger?.error("Couldn't create account for chain \(chainAsset.chain.chainId)")
            return
        }

        let key = chainAsset.uniqueKey(accountId: accountId)
        guard getSubscription(for: key) == nil else {
            return
        }

        let maybeSubscriptionId = remoteSubscriptionService.attachToAccountInfo(
            of: accountId,
            chainAsset: chainAsset,
            queue: nil,
            closure: closure
        )

        if let subsciptionId = maybeSubscriptionId {
            let subscription = SubscriptionInfo(
                subscriptionId: subsciptionId,
                accountId: accountId
            )

            setSubscription(subscription, for: chainAsset.uniqueKey(accountId: accountId))
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

        remoteSubscriptionService.detachFromAccountInfo(
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

    private func removeSubscription(for key: ChainAssetKey) {
        guard let subscriptionInfo = getSubscription(for: key) else {
            logger?.error("Expected to remove subscription but not found for \(key)")
            return
        }

        setSubscription(nil, for: key)

        remoteSubscriptionService.detachFromAccountInfo(
            for: subscriptionInfo.subscriptionId,
            chainAssetKey: key,
            queue: nil,
            closure: nil
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
        unsubscribeFromChains()

        self.selectedMetaAccount = selectedMetaAccount

        subscribeToChains()
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

    func processChainSyncDidComplete(event: ChainSyncDidComplete) {
        event.newOrUpdatedChains.forEach { chain in
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
