import Foundation
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels

class BaseStakingAccountSubscription: StakingAccountSubscription {
    struct Subscription {
        let handlers: [StorageChildSubscribing]
        let subscriptionId: UInt16
    }

    let accountId: AccountId
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?
    let mutex = NSLock()
    private let stakingType: StakingType
    private let chainFormat: ChainFormat
    private let provider: StreamableProvider<StashItem>
    private let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    private var subscription: Subscription?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        chainFormat: ChainFormat,
        chainRegistry: ChainRegistryProtocol,
        provider: StreamableProvider<StashItem>,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        logger: LoggerProtocol? = nil,
        stakingType: StakingType
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.chainFormat = chainFormat
        self.chainRegistry = chainRegistry
        self.provider = provider
        self.childSubscriptionFactory = childSubscriptionFactory
        self.operationQueue = operationQueue
        self.logger = logger
        self.stakingType = stakingType
    }

    func resolveKeysAndSubscribe() {
        if stakingType.isRelaychain {
            subscribeLocal()
        } else {
            subscribeRemote(for: accountId)
        }
    }

    deinit {
        unsubscribeRemote()
    }

    func subscribeLocal() {
        let changesClosure: ([DataProviderChange<StashItem>]) -> Void = { [weak self] changes in
            let stashItem: StashItem? = changes.reduce(nil) { _, item in
                switch item {
                case let .insert(newItem), let .update(newItem):
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

        provider.addObserver(
            self,
            deliverOn: .global(qos: .userInitiated),
            executing: changesClosure,
            failing: failureClosure,
            options: StreamableProviderObserverOptions.substrateSource()
        )
    }

    func unsubscribeRemote() {
        mutex.lock()

        if let subscriptionId = subscription?.subscriptionId {
            chainRegistry.getConnection(for: chainAsset.chain.chainId)?.cancelForIdentifier(subscriptionId)
        }

        subscription = nil

        mutex.unlock()
    }

    func createRequest(for stashItem: StashItem) throws -> [(StorageCodingPath, Data)] {
        var requests: [(StorageCodingPath, Data)] = []

        let stashId = try stashItem.stash.toAccountId(using: chainFormat)

        if stashId != accountId {
            requests.append((.controller, stashId))
            requests.append((.account, stashId))
        }

        let controllerId = try stashItem.controller.toAccountId(using: chainFormat)

        if controllerId != accountId {
            requests.append((.stakingLedger, controllerId))
            requests.append((.account, controllerId))
        }

        requests.append((.nominators, stashId))
        requests.append((.validatorPrefs, stashId))
        requests.append((.payee, stashId))

        return requests
    }

    func createRequest(for accountId: AccountId) throws -> [(StorageCodingPath, Data)] {
        var requests: [(StorageCodingPath, Data)] = []

        requests.append((.delegatorState, accountId))
        requests.append((.delegationScheduledRequests, accountId))

        return requests
    }

    func subscribeRemote(for accountId: AccountId) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let requests = try createRequest(for: accountId)

            let localKeyFactory = LocalStorageKeyFactory()
            let localKeys = try requests.map { request -> String in
                let storagePath = request.0
                let accountId = request.1
                let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)

                let localKey = try localKeyFactory.createFromStoragePath(
                    storagePath,
                    chainAssetKey: chainAssetKey
                )

                return localKey
            }

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let storageKeyFactory = StorageKeyFactory()

            let codingOperations: [MapKeyEncodingOperation<Data>] = requests.map { request in
                MapKeyEncodingOperation(
                    path: request.0,
                    storageKeyFactory: storageKeyFactory,
                    keyParams: [request.1]
                )
            }

            configureMapOperations(codingOperations, coderFactoryOperation: codingFactoryOperation)

            let mapOperation = ClosureOperation {
                try codingOperations.map { try $0.extractNoCancellableResultData()[0] }
            }

            codingOperations.forEach { mapOperation.addDependency($0) }

            mapOperation.completionBlock = { [weak self] in
                do {
                    let remoteKeys = try mapOperation.extractNoCancellableResultData()
                    let keysList = zip(remoteKeys, localKeys).map {
                        SubscriptionStorageKeys(remote: $0.0, local: $0.1)
                    }

                    self?.subscribeToRemote(with: keysList)
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }

            let operations = [codingFactoryOperation] + codingOperations + [mapOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } catch {
            logger?.error("Did receive unexpected error \(error)")
        }
    }

    func subscribeRemote(for stashItem: StashItem) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let requests = try createRequest(for: stashItem)

            let localKeyFactory = LocalStorageKeyFactory()
            let localKeys = try requests.map { request -> String in
                let storageParh = request.0
                let accountId = request.1
                let chainAssetKey = chainAsset.uniqueKey(accountId: accountId)

                let localKey = try localKeyFactory.createFromStoragePath(
                    storageParh,
                    chainAssetKey: chainAssetKey
                )

                return localKey
            }

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let storageKeyFactory = StorageKeyFactory()

            let codingOperations: [MapKeyEncodingOperation<Data>] = requests.map { request in
                MapKeyEncodingOperation(
                    path: request.0,
                    storageKeyFactory: storageKeyFactory,
                    keyParams: [request.1]
                )
            }

            configureMapOperations(codingOperations, coderFactoryOperation: codingFactoryOperation)

            let mapOperation = ClosureOperation {
                try codingOperations.map { try $0.extractNoCancellableResultData()[0] }
            }

            codingOperations.forEach { mapOperation.addDependency($0) }

            mapOperation.completionBlock = { [weak self] in
                do {
                    let remoteKeys = try mapOperation.extractNoCancellableResultData()
                    let keysList = zip(remoteKeys, localKeys).map {
                        SubscriptionStorageKeys(remote: $0.0, local: $0.1)
                    }

                    self?.subscribeToRemote(with: keysList)
                } catch {
                    self?.logger?.error("Did receive error: \(error)")
                }
            }

            let operations = [codingFactoryOperation] + codingOperations + [mapOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } catch {
            logger?.error("Did receive unexpected error \(error)")
        }
    }

    func subscribeToRemote(
        with keysList: [SubscriptionStorageKeys]
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            let storageParams = keysList.map { $0.remote.toHex(includePrefix: true) }

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try connection.subscribe(
                RPCMethod.storageSubscribe,
                params: [storageParams],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            let handlers: [StorageChildSubscribing] = keysList.map { keys in
                childSubscriptionFactory.createEmptyHandlingSubscription(keys: keys)
            }

            subscription = Subscription(handlers: handlers, subscriptionId: subscriptionId)

        } catch {
            logger?.error("Can't subscribe to storage: \(error)")
        }
    }

    func configureMapOperations<T: Encodable>(
        _ operations: [MapKeyEncodingOperation<T>],
        coderFactoryOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) {
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

    func handleUpdate(_ update: StorageUpdate) {
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

    func applyHandler(_ handler: StorageChildSubscribing, for update: StorageUpdateData) {
        if let change = update.changes.first(where: { $0.key == handler.remoteStorageKey }) {
            handler.processUpdate(change.value, blockHash: update.blockHash)
        }
    }
}
