import Foundation
import RobinHood
import SSFModels
import SSFUtils

typealias RemoteSubscriptionClosure = (Result<Void, Error>) -> Void

enum RemoteSubscriptionServiceError: Error {
    case remoteKeysNotMatchLocal
}

class RemoteSubscriptionService<T: StorageWrapper> {
    struct Callback {
        let queue: DispatchQueue
        let closure: RemoteSubscriptionClosure
    }

    class Active {
        var subscriptionIds: Set<UUID>
        let container: StorageSubscriptionContainer

        init(subscriptionIds: Set<UUID>, container: StorageSubscriptionContainer) {
            self.subscriptionIds = subscriptionIds
            self.container = container
        }
    }

    class Pending {
        var subscriptionIds: Set<UUID>
        let wrapper: CompoundOperationWrapper<StorageSubscriptionContainer>
        var callbacks: [UUID: Callback]

        init(
            subscriptionIds: Set<UUID>,
            wrapper: CompoundOperationWrapper<StorageSubscriptionContainer>,
            callbacks: [UUID: Callback]
        ) {
            self.subscriptionIds = subscriptionIds
            self.wrapper = wrapper
            self.callbacks = callbacks
        }
    }

    private let chainRegistry: ChainRegistryProtocol
    private let repository: AnyDataProviderRepository<T>
    private let operationManager: OperationManagerProtocol
    private let logger: LoggerProtocol

    private var activeSubscriptions: [String: Active] = [:]
    private var pendingSubscriptions: [String: Pending] = [:]

    private let mutex = NSLock()

    private lazy var localStorageKeyFactory = LocalStorageKeyFactory()
    private lazy var remoteStorageKeyFactory = StorageKeyFactory()

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<T>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.operationManager = operationManager
        self.logger = logger
    }

    func attachToSubscription(
        with requests: [SubscriptionRequestProtocol],
        chainId: ChainModel.Id,
        cacheKey: String,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) -> UUID {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let subscriptionId = UUID()

        if let active = activeSubscriptions[cacheKey] {
            active.subscriptionIds.insert(subscriptionId)

            callbackClosureIfProvided(closure, queue: queue, result: .success(()))

            return subscriptionId
        }

        if let pending = pendingSubscriptions[cacheKey] {
            pending.subscriptionIds.insert(subscriptionId)

            if let closure = closure {
                pending.callbacks[subscriptionId] = Callback(queue: queue ?? .main, closure: closure)
            }

            return subscriptionId
        }

        let wrapper = subscriptionOperation(using: requests, chainId: chainId)

        wrapper.targetOperation.completionBlock = { [weak self] in
            switch wrapper.targetOperation.result {
            case let .failure(error):
                self?.logger.error("chain: \(chainId) has error: \(error)")
            case let .success(container):
                DispatchQueue.global(qos: .default).async {
                    self?.mutex.lock()

                    defer {
                        self?.mutex.unlock()
                    }

                    self?.handleSubscriptionInitResult(.success(container), cacheKey: cacheKey)
                }
            default:
                break
            }
        }

        let pending = Pending(
            subscriptionIds: [subscriptionId],
            wrapper: wrapper,
            callbacks: [:]
        )

        if let closure = closure {
            pending.callbacks[subscriptionId] = Callback(queue: queue ?? .main, closure: closure)
        }

        pendingSubscriptions[cacheKey] = pending

        operationManager.enqueue(operations: wrapper.allOperations, in: .transient)

        return subscriptionId
    }

    func detachFromSubscription(
        _ cacheKey: String,
        subscriptionId: UUID,
        queue: DispatchQueue?,
        closure: RemoteSubscriptionClosure?
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let active = activeSubscriptions[cacheKey] {
            active.subscriptionIds.remove(subscriptionId)

            if active.subscriptionIds.isEmpty {
                activeSubscriptions[cacheKey] = nil
            }

            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        } else if let pending = pendingSubscriptions[cacheKey] {
            pending.subscriptionIds.remove(subscriptionId)
            pending.callbacks[subscriptionId] = nil

            if pending.subscriptionIds.isEmpty {
                pendingSubscriptions[cacheKey] = nil
                pending.wrapper.cancel()
            }

            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        } else {
            callbackClosureIfProvided(closure, queue: queue ?? .main, result: .success(()))
        }
    }

    private func subscriptionOperation(
        using requests: [SubscriptionRequestProtocol],
        chainId: ChainModel.Id
    ) -> CompoundOperationWrapper<StorageSubscriptionContainer> {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(
                ChainRegistryError.runtimeMetadaUnavailable
            )
        }

        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let keyEncodingWrappers: [CompoundOperationWrapper<Data>] = requests.map { request in
            let wrapper = request.createKeyEncodingWrapper(using: remoteStorageKeyFactory) {
                try coderFactoryOperation.extractNoCancellableResultData()
            }

            wrapper.addDependency(operations: [coderFactoryOperation])

            return wrapper
        }

        let containerOperation = ClosureOperation<StorageSubscriptionContainer> { [weak self] in

            guard let strongSelf = self else {
                throw BaseOperationError.unexpectedDependentResult
            }
            let remoteKeys = try keyEncodingWrappers.map { try $0.targetOperation.extractNoCancellableResultData() }
            let localKeys = requests.map(\.localKey)

            let container = try strongSelf.createContainer(
                for: chainId,
                remoteKeys: remoteKeys,
                localKeys: localKeys
            )

            return container
        }

        keyEncodingWrappers.forEach { containerOperation.addDependency($0.targetOperation) }

        let allWrapperOperations = keyEncodingWrappers.flatMap(\.allOperations)

        return CompoundOperationWrapper(
            targetOperation: containerOperation,
            dependencies: [coderFactoryOperation] + allWrapperOperations
        )
    }

    private func createContainer(
        for chainId: ChainModel.Id,
        remoteKeys: [Data],
        localKeys: [String]
    ) throws -> StorageSubscriptionContainer {
        guard remoteKeys.count == localKeys.count else {
            throw RemoteSubscriptionServiceError.remoteKeysNotMatchLocal
        }

        guard let connection = chainRegistry.getConnection(for: chainId) else {
            throw ChainRegistryError.connectionUnavailable
        }

        let subscriptions = zip(remoteKeys, localKeys).map { keysPair in
            EmptyHandlingStorageSubscription<T>(
                remoteStorageKey: keysPair.0,
                localStorageKey: keysPair.1,
                storage: repository,
                operationManager: operationManager,
                logger: logger
            )
        }

        let container = StorageSubscriptionContainer(
            engine: connection,
            children: subscriptions,
            logger: logger
        )

        return container
    }

    func handleSubscriptionInitResult(_ result: Result<StorageSubscriptionContainer, Error>?, cacheKey: String) {
        guard let pending = pendingSubscriptions[cacheKey] else {
            return
        }

        switch result {
        case let .success(container):
            if !pending.subscriptionIds.isEmpty {
                let active = Active(subscriptionIds: pending.subscriptionIds, container: container)
                activeSubscriptions[cacheKey] = active
            }

            clearPendingWithResult(.success(()), for: cacheKey)
        case let .failure(error):
            clearPendingWithResult(.failure(error), for: cacheKey)
        case .none:
            clearPendingWithResult(.failure(BaseOperationError.parentOperationCancelled), for: cacheKey)
        }
    }

    private func clearPendingWithResult(_ result: Result<Void, Error>, for cacheKey: String) {
        guard let pendings = pendingSubscriptions[cacheKey] else {
            return
        }

        pendingSubscriptions[cacheKey] = nil

        for pending in pendings.callbacks.values {
            pending.queue.async {
                pending.closure(result)
            }
        }
    }
}
