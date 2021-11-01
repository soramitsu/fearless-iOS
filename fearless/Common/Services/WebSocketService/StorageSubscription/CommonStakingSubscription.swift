import Foundation
import RobinHood
import FearlessUtils

final class CommonStakingSubscription: WebSocketSubscribing {
    struct Subscription {
        let handlers: [StorageChildSubscribing]
        let subscriptionId: UInt16
    }

    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let engine: JSONRPCEngine
    let logger: LoggerProtocol?

    private let mutex = NSLock()

    private var subscription: Subscription?

    deinit {
        unsubscribeRemote()
    }

    init(
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.engine = engine
        self.runtimeService = runtimeService
        self.childSubscriptionFactory = childSubscriptionFactory
        self.operationManager = operationManager
        self.logger = logger

        resolveSubscription()
    }

    private func resolveSubscription() {
        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        logger?.debug("Will start resolving subscriptions")

        let remoteKeyOperation = ClosureOperation<[Data]> {
            let metadata = try coderFactoryOperation.extractNoCancellableResultData().metadata

            let storageKeyFactory = StorageKeyFactory()

            var keys: [Data] = []

            if metadata.getStorageMetadata(for: .minNominatorBond) != nil {
                let key = try storageKeyFactory.key(from: .minNominatorBond)
                keys.append(key)
            }

            if metadata.getStorageMetadata(for: .maxNominatorsCount) != nil {
                let key = try storageKeyFactory.key(from: .maxNominatorsCount)
                keys.append(key)
            }

            if metadata.getStorageMetadata(for: .counterForNominators) != nil {
                let key = try storageKeyFactory.key(from: .counterForNominators)
                keys.append(key)
            }

            return keys
        }

        remoteKeyOperation.addDependency(coderFactoryOperation)

        remoteKeyOperation.completionBlock = { [weak self] in
            do {
                let remoteKeys = try remoteKeyOperation.extractNoCancellableResultData()

                if !remoteKeys.isEmpty {
                    self?.completeSubscription(for: remoteKeys)
                } else {
                    self?.logger?.warning("No remote key found for common staking subscription")
                }
            } catch {
                self?.logger?.error("Staking keys resolution error: \(error)")
            }
        }

        operationManager.enqueue(operations: [coderFactoryOperation, remoteKeyOperation], in: .transient)
    }

    private func completeSubscription(for remoteKeys: [Data]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            let childSubscriptions = remoteKeys.map {
                childSubscriptionFactory.createEmptyHandlingSubscription(remoteKey: $0)
            }

            let storageParams = remoteKeys.map { $0.toHex(includePrefix: true) }

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try engine.subscribe(
                RPCMethod.storageSubscribe,
                params: [storageParams],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            subscription = Subscription(handlers: childSubscriptions, subscriptionId: subscriptionId)

        } catch {
            logger?.error("Can't complete staking subscription: \(error)")
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let subscription = subscription else {
            logger?.warning("Common staking update received but subscription is missing")
            return
        }

        let updateData = StorageUpdateData(update: update)

        subscription.handlers.forEach { applyHandler($0, for: updateData) }
    }

    private func applyHandler(_ handler: StorageChildSubscribing, for update: StorageUpdateData) {
        if let change = update.changes.first(where: { $0.key == handler.remoteStorageKey }) {
            handler.processUpdate(change.value, blockHash: update.blockHash)
        }
    }

    private func unsubscribeRemote() {
        mutex.lock()

        if let subscriptionId = subscription?.subscriptionId {
            engine.cancelForIdentifier(subscriptionId)
        }

        subscription = nil

        mutex.unlock()
    }
}
