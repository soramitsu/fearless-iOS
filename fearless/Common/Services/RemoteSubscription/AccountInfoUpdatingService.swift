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
    let chainRegistry: ChainRegistryProtocol
    let remoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    let logger: LoggerProtocol?
    let eventCenter: EventCenterProtocol

    private var subscribedChains: [ChainModel.Id: SubscriptionInfo] = [:]

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

        for chainId in subscribedChains.keys {
            removeSubscription(for: chainId)
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
                addSubscriptionIfNeeded(for: newItem)
            case .update:
                break
            case let .delete(deletedIdentifier):
                removeSubscription(for: deletedIdentifier)
            }
        }
    }

    private func addSubscriptionIfNeeded(for chain: ChainModel) {
        guard let accountId = selectedMetaAccount.fetch(for: chain.accountRequest())?.accountId else {
            logger?.error("Couldn't create account for chain \(chain.chainId)")
            return
        }

        guard subscribedChains[chain.chainId] == nil else {
            return
        }

        let maybeSubscriptionId = remoteSubscriptionService.attachToAccountInfo(
            of: accountId,
            chainId: chain.chainId,
            queue: nil,
            closure: nil
        )

        if let subsciptionId = maybeSubscriptionId {
            subscribedChains[chain.chainId] = SubscriptionInfo(
                subscriptionId: subsciptionId,
                accountId: accountId
            )
        }
    }

    private func removeSubscription(for chainId: ChainModel.Id) {
        guard let subscriptionInfo = subscribedChains[chainId] else {
            logger?.error("Expected to remove subscription but not found for \(chainId)")
            return
        }

        subscribedChains[chainId] = nil

        remoteSubscriptionService.detachFromAccountInfo(
            for: subscriptionInfo.subscriptionId,
            accountId: subscriptionInfo.accountId,
            chainId: chainId,
            queue: nil,
            closure: nil
        )
    }

    private func subscribeToChains() {
        chainRegistry.chainsSubscribe(
            self,
            runningInQueue: .global(qos: .userInitiated)
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
            removeSubscription(for: chain.chainId)
            addSubscriptionIfNeeded(for: chain)
        }
    }
}
