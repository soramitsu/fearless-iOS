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
    }

    private(set) var selectedMetaAccount: MetaAccountModel
    private let chainRegistry: ChainRegistryProtocol
    private let substrateRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    private let ethereumRemoteSubscriptionService: WalletRemoteSubscriptionServiceProtocol
    private let logger: LoggerProtocol?
    private let eventCenter: EventCenterProtocol
    private var chains: [ChainModel.Id: ChainModel] = [:]

    private var subscribedChains: [ChainModel.Id: SubscriptionInfo] = [:]

    private let mutex = NSLock()
    private lazy var readLock = ReaderWriterLock()

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
                chains[newItem.chainId] = newItem

                if chainRegistry.availableChainIds.or([]).contains(newItem.chainId) {
                    addSubscriptionIfNeeded(for: newItem)
                }
            case .update:
                break
            case let .delete(deletedIdentifier):
                removeSubscription(for: deletedIdentifier)
            }
        }
    }

    private func addSubscriptionIfNeeded(for chainModel: ChainModel, closure: RemoteSubscriptionClosure? = nil) {
        guard !chainModel.isEthereum else {
            return
        }
        
        guard getSubscription(for: chainModel.chainId) == nil else {
            return
        }

        let maybeSubscriptionId = remoteSubscriptionService.attachToAccountInfo(
            wallet: selectedMetaAccount,
            chainModel: chainModel,
            queue: nil,
            closure: closure
        )

        if let subsciptionId = maybeSubscriptionId {
            let subscription = SubscriptionInfo(subscriptionId: subsciptionId)
            setSubscription(subscription, for: chainModel.chainId)
        }
    }

    private func setSubscription(_ subscription: SubscriptionInfo?, for key: String) {
        readLock.exclusivelyWrite { [weak self] in
            self?.subscribedChains[key] = subscription
        }
    }

    private func getSubscription(for key: ChainModel.Id) -> SubscriptionInfo? {
        readLock.concurrentlyRead { subscribedChains[key] }
    }

    private func updateSubscription(for chainModel: ChainModel) {
        guard let subscriptionInfo = getSubscription(for: chainModel.chainId) else {
            logger?.error("Expected to update subscription but not found for \(chainModel.name)")
            return
        }

        getRemoteSubscriptionService(for: chainAsset).detachFromAccountInfo(
            for: subscriptionInfo.subscriptionId,
            chainId: chainModel.chainId,
            queue: nil
        ) { [weak self] _ in
            self?.setSubscription(nil, for: chainModel.chainId)
            self?.addSubscriptionIfNeeded(for: chainModel) { result in
                switch result {
                case .success:
                    let event = WalletRemoteSubscriptionWasUpdatedEvent(chainModel: chainModel)
                    self?.eventCenter.notify(with: event)
                case let .failure(error):
                    self?.logger?.error("Can't add subscription if nedded error: \(error)")
                }
            }
        }
    }

    private func removeSubscription(for chainId: ChainModel.Id) {
        guard let subscriptionInfo = getSubscription(for: chainId) else {
            logger?.error("Expected to remove subscription but not found for \(chainId)")
            return
        }

        setSubscription(nil, for: chainId)

        guard let ecosystem = key.components(separatedBy: ":")[safe: 1],
              let chainBaseType = ChainBaseType(rawValue: ecosystem) else {
            return
        }

        switch chainBaseType {
        case .ethereum:
            ethereumRemoteSubscriptionService.detachFromAccountInfo(
                for: subscriptionInfo.subscriptionId,
                chainId: chainId,
                queue: nil,
                closure: nil
            )
        case .substrate:
            substrateRemoteSubscriptionService.detachFromAccountInfo(
                for: subscriptionInfo.subscriptionId,
                chainId: chainId,
                queue: nil,
                closure: nil
            )
        }
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
            updateSubscription(for: chain)
        }
    }

    func processRuntimeSnapshorReady(event: RuntimeSnapshotReady) {
        updateSubscription(for: event.chainModel)
    }
}
