import Foundation
import RobinHood

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    )

    func chainsUnsubscribe(_ target: AnyObject)

    func syncUp()
}

final class ChainRegistry {
    let runtimeProviderPool: RuntimeProviderPoolProtocol
    let connectionPool: ConnectionPoolProtocol
    let chainSyncService: ChainSyncServiceProtocol
    let runtimeSyncService: RuntimeSyncServiceProtocol
    let commonTypesSyncService: CommonTypesSyncServiceProtocol
    let chainProvider: StreamableProvider<ChainModel>
    let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    let processingQueue = DispatchQueue(label: "jp.co.soramitsu.chain.registry")
    let logger: LoggerProtocol?

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]

    private let mutex = NSLock()

    init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPool: ConnectionPoolProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        runtimeSyncService: RuntimeSyncServiceProtocol,
        commonTypesSyncService: CommonTypesSyncServiceProtocol,
        chainProvider: StreamableProvider<ChainModel>,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPool = connectionPool
        self.chainSyncService = chainSyncService
        self.runtimeSyncService = runtimeSyncService
        self.commonTypesSyncService = commonTypesSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
        self.logger = logger

        subscribeToChains()
    }

    private func subscribeToChains() {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { [weak self] changes in
            self?.handle(changes: changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .userInitiated),
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    private func handle(changes: [DataProviderChange<ChainModel>]) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard !changes.isEmpty else {
            return
        }

        changes.forEach { change in
            do {
                switch change {
                case let .insert(newChain):
                    let connection = try connectionPool.setupConnection(for: newChain)
                    _ = runtimeProviderPool.setupRuntimeProvider(for: newChain)

                    runtimeSyncService.register(chain: newChain, with: connection)

                    setupRuntimeVersionSubscription(for: newChain, connection: connection)
                case let .update(updatedChain):
                    _ = try connectionPool.setupConnection(for: updatedChain)
                    _ = runtimeProviderPool.setupRuntimeProvider(for: updatedChain)
                case let .delete(chainId):
                    runtimeProviderPool.destroyRuntimeProvider(for: chainId)
                    clearRuntimeSubscription(for: chainId)

                    runtimeSyncService.unregister(chainId: chainId)
                }
            } catch {
                logger?.error("Unexpected error on handling chains update: \(error)")
            }
        }
    }

    private func setupRuntimeVersionSubscription(for chain: ChainModel, connection: ChainConnection) {
        let subscription = specVersionSubscriptionFactory.createSubscription(
            for: chain.chainId,
            connection: connection
        )

        subscription.subscribe()

        runtimeVersionSubscriptions[chain.chainId] = subscription
    }

    private func clearRuntimeSubscription(for chainId: ChainModel.Id) {
        if let subscription = runtimeVersionSubscriptions[chainId] {
            subscription.unsubscribe()
        }

        runtimeVersionSubscriptions[chainId] = nil
    }

    private func syncUpServices() {
        chainSyncService.syncUp()
        commonTypesSyncService.syncUp()
    }
}

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Set(runtimeVersionSubscriptions.keys)
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connectionPool.getConnection(for: chainId)
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return runtimeProviderPool.getRuntimeProvider(for: chainId)
    }

    func chainsSubscribe(
        _ target: AnyObject,
        runningInQueue: DispatchQueue,
        updateClosure: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        let updateClosure: ([DataProviderChange<ChainModel>]) -> Void = { changes in
            runningInQueue.async {
                updateClosure(changes)
            }
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        chainProvider.addObserver(
            target,
            deliverOn: processingQueue,
            executing: updateClosure,
            failing: failureClosure,
            options: options
        )
    }

    func chainsUnsubscribe(_ target: AnyObject) {
        chainProvider.removeObserver(target)
    }

    func syncUp() {
        syncUpServices()
    }
}
