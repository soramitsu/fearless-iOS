import Foundation
import RobinHood
import IrohaCrypto
import FearlessUtils

final class StakingAccountSubscription: WebSocketSubscribing {
    struct Subscription {
        let handlers: [StorageChildSubscribing]
        let subscriptionId: UInt16
    }

    let address: String
    let chain: Chain
    let provider: StreamableProvider<StashItem>
    let runtimeService: RuntimeCodingServiceProtocol
    let addressFactory: SS58AddressFactoryProtocol
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    let operationManager: OperationManagerProtocol
    let engine: JSONRPCEngine
    let logger: LoggerProtocol?

    private let mutex = NSLock()

    private var subscription: Subscription?

    init(address: String,
         chain: Chain,
         engine: JSONRPCEngine,
         provider: StreamableProvider<StashItem>,
         runtimeService: RuntimeCodingServiceProtocol,
         childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
         operationManager: OperationManagerProtocol,
         addressFactory: SS58AddressFactoryProtocol,
         logger: LoggerProtocol?) {
        self.address = address
        self.chain = chain
        self.engine = engine
        self.provider = provider
        self.operationManager = operationManager
        self.runtimeService = runtimeService
        self.childSubscriptionFactory = childSubscriptionFactory
        self.addressFactory = addressFactory
        self.logger = logger

        subscribeLocal()
    }

    deinit {
        unsubscribeRemote()
    }

    private func subscribeLocal() {
        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] (changes) in
            let stashItem: StashItem? = changes.reduce(nil) { (_, item) in
                switch item {
                case .insert(let newItem), .update(let newItem):
                    return newItem
                case .delete:
                    return nil
                }
            }

            self?.unsubscribeRemote()

            if let stashItem = stashItem {
                self?.subscribeRemote(for: stashItem)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Did receive error: \(error)")
        }

        provider.addObserver(self,
                             deliverOn: .global(qos: .userInitiated),
                             executing: changesClosure,
                             failing: failureClosure,
                             options: StreamableProviderObserverOptions.substrateSource())
    }

    private func unsubscribeRemote() {
        mutex.lock()

        if let subscriptionId = subscription?.subscriptionId {
            engine.cancelForIdentifier(subscriptionId)
        }

        self.subscription = nil

        mutex.unlock()
    }

    private func subscribeRemote(for stashItem: StashItem) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            var requests: [(StorageCodingPath, Data)] = []

            let stashId = try addressFactory.accountId(from: stashItem.stash)

            if stashItem.stash != address {
                requests.append((.controller, stashId))
            }

            if stashItem.controller != address {
                let controllerId = try addressFactory.accountId(from: stashItem.controller)
                requests.append((.stakingLedger, controllerId))
            }

            requests.append((.nominators, stashId))
            requests.append((.validatorPrefs, stashId))

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let storageKeyFactory = StorageKeyFactory()

            let codingOperations: [MapKeyEncodingOperation<Data>] = requests.map { request in
                MapKeyEncodingOperation(path: request.0,
                                        storageKeyFactory: storageKeyFactory,
                                        keyParams: [request.1])
            }

            configureMapOperations(codingOperations, coderFactoryOperation: codingFactoryOperation)

            let mapOperation = ClosureOperation {
                try codingOperations.map { try $0.extractNoCancellableResultData()[0] }
            }

            codingOperations.forEach { mapOperation.addDependency($0) }

            mapOperation.completionBlock = { [weak self] in
                do {
                    let keys = try mapOperation.extractNoCancellableResultData()

                    let ledgerKey: Data?
                    if let ledgerOperation = codingOperations.first(where: { $0.path == .stakingLedger }) {
                        ledgerKey = try ledgerOperation.extractNoCancellableResultData().first
                    } else {
                        ledgerKey = nil
                    }

                    self?.subscribeToRemote(with: keys, ledgerKey: ledgerKey)
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }

            let operations = [codingFactoryOperation] + codingOperations + [mapOperation]

            operationManager.enqueue(operations: operations, in: .transient)

        } catch {
            logger?.error("Did receive unexpected error \(error)")
        }
    }

    private func subscribeToRemote(with keys: [Data], ledgerKey: Data?) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            let storageParams = keys.map { $0.toHex(includePrefix: true) }

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] (update) in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] (error, unsubscribed) in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try engine.subscribe(RPCMethod.storageSubscibe,
                                                      params: [storageParams],
                                                      updateClosure: updateClosure,
                                                      failureClosure: failureClosure)

            let handlers: [StorageChildSubscribing] = keys.map { key in
                if key == ledgerKey {
                    return childSubscriptionFactory
                        .createEventEmittingSubscription(remoteKey: key) { _ in WalletStakingInfoChanged() }
                } else {
                    return childSubscriptionFactory.createEmptyHandlingSubscription(remoteKey: key)
                }
            }
            subscription = Subscription(handlers: handlers, subscriptionId: subscriptionId)

        } catch {
            logger?.error("Can't subscribe to storage: \(error)")
        }
    }

    private func configureMapOperations(_ operations: [MapKeyEncodingOperation<Data>],
                                        coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>) {
        operations.forEach { operation in
            operation.addDependency(coderFactoryOperation)

            operation.configurationBlock = {
                do {
                    guard let result = try coderFactoryOperation.extractResultData() else {
                        operation.cancel()
                        return
                    }

                    operation.codingFactory = result

                } catch {
                    operation.result = .failure(error)
                }
            }
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

        subscription.handlers.forEach { applyHandler($0, for: updateData) }
    }

    private func applyHandler(_ handler: StorageChildSubscribing, for update: StorageUpdateData) {
        if let change = update.changes.first(where: { $0.key == handler.remoteStorageKey }) {
            handler.processUpdate(change.value, blockHash: update.blockHash)
        }
    }
}
