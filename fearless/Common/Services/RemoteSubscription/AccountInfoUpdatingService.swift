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
        mutex.lock()

        defer {
            mutex.unlock()
        }

        for chainAssetKey in subscribedChains.keys {
            removeSubscription(for: chainAssetKey)
        }
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

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

    private func addSubscriptionIfNeeded(for chainAsset: ChainAsset) {
        guard let accountId = selectedMetaAccount.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            logger?.error("Couldn't create account for chain \(chainAsset.chain.chainId)")
            return
        }

        guard subscribedChains[chainAsset.uniqueKey(accountId: accountId)] == nil else {
            return
        }

        let maybeSubscriptionId = remoteSubscriptionService.attachToAccountInfo(
            of: accountId,
            chainAsset: chainAsset,
            queue: nil,
            closure: nil
        )

        if let subsciptionId = maybeSubscriptionId {
            subscribedChains[chainAsset.uniqueKey(accountId: accountId)] = SubscriptionInfo(
                subscriptionId: subsciptionId,
                accountId: accountId
            )
        }
    }

    private func removeSubscription(for key: ChainAssetKey) {
        guard let subscriptionInfo = subscribedChains[key] else {
            logger?.error("Expected to remove subscription but not found for \(key)")
            return
        }

        subscribedChains[key] = nil

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
                guard let accountId = selectedMetaAccount.fetch(for: $0.chain.accountRequest())?.accountId else {
                    return
                }
                let key = $0.uniqueKey(accountId: accountId)
                removeSubscription(for: key)
                addSubscriptionIfNeeded(for: $0)
            }
        }
    }
}
