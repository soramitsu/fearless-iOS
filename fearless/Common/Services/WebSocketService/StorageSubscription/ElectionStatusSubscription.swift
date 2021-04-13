import Foundation
import RobinHood
import FearlessUtils

final class ElectionStatusSubscription: WebSocketSubscribing {
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let operationManager: OperationManagerProtocol
    let engine: JSONRPCEngine
    let logger: LoggerProtocol?

    private let mutex = NSLock()

    private var subscription: StorageChildSubscribing?
    private var subscriptionId: UInt16?

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

        let remoteKeyOperation = ClosureOperation<Data?> {
            let metadata = try coderFactoryOperation.extractNoCancellableResultData().metadata

            let storageKeyFactory = StorageKeyFactory()

            if metadata.getStorageMetadata(for: .electionStatus) != nil {
                return try storageKeyFactory.key(from: .electionStatus)
            }

            if metadata.getStorageMetadata(for: .electionPhase) != nil {
                return try storageKeyFactory.key(from: .electionPhase)
            }

            return Data()
        }

        remoteKeyOperation.addDependency(coderFactoryOperation)

        remoteKeyOperation.completionBlock = { [weak self] in
            do {
                if let remoteKey = try remoteKeyOperation.extractNoCancellableResultData() {
                    self?.completeSubscription(for: remoteKey)
                } else {
                    self?.logger?.warning("No remote key found for election status")
                }
            } catch {
                self?.logger?.error("Election status key resolution error: \(error)")
            }
        }

        operationManager.enqueue(operations: [coderFactoryOperation, remoteKeyOperation], in: .transient)
    }

    private func completeSubscription(for remoteKey: Data) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            subscription = childSubscriptionFactory.createEmptyHandlingSubscription(remoteKey: remoteKey)

            let storageParams = [remoteKey.toHex(includePrefix: true)]

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            subscriptionId = try engine.subscribe(
                RPCMethod.storageSubscibe,
                params: [storageParams],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )
        } catch {
            logger?.error("Can't complete election status subscription: \(error)")
        }
    }

    private func handleUpdate(_ update: StorageUpdate) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let subscription = subscription else {
            logger?.warning("Staking update received but subscription is missing")
            return
        }

        let updateData = StorageUpdateData(update: update)

        if let change = updateData.changes.first {
            subscription.processUpdate(change.value, blockHash: updateData.blockHash)

            if let value = change.value?.toHex() {
                logger?.debug("Did handle new election status: \(value)")
            } else {
                logger?.debug("Did handle new election status nil")
            }
        }
    }

    private func unsubscribeRemote() {
        mutex.lock()

        if let subscriptionId = subscriptionId {
            engine.cancelForIdentifier(subscriptionId)
        }

        subscription = nil

        mutex.unlock()
    }
}
