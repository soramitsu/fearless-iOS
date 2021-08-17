import Foundation
import RobinHood

typealias ChainRegistrySetupClosure = (Set<ChainModel.Id>) -> Void

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?

    func waitForSetupCompletion(with closure: @escaping ChainRegistrySetupClosure)

    func syncUp()
}

final class ChainRegistry {
    let runtimeProviderPool: RuntimeProviderPoolProtocol
    let connectionPool: ConnectionPoolProtocol
    let chainSyncService: ChainSyncServiceProtocol
    let commonTypesSyncService: CommonTypesSyncServiceProtocol
    let chainProvider: StreamableProvider<ChainModel>
    let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    let logger: LoggerProtocol?

    private(set) var waiters: [ChainRegistrySetupClosure] = []

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol]?

    private let mutex = NSLock()

    init(
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPool: ConnectionPoolProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        commonTypesSyncService: CommonTypesSyncServiceProtocol,
        chainProvider: StreamableProvider<ChainModel>,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPool = connectionPool
        self.chainSyncService = chainSyncService
        self.commonTypesSyncService = commonTypesSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
        self.logger = logger

        subscribeToChains()
        syncUpServices()
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

        let isSetup: Bool

        if runtimeVersionSubscriptions == nil {
            runtimeVersionSubscriptions = [:]

            isSetup = true
        } else {
            isSetup = false
        }

        changes.forEach { change in
            do {
                switch change {
                case let .insert(newChain):
                    let connection = try connectionPool.setupConnection(for: newChain)
                    _ = runtimeProviderPool.setupRuntimeProvider(for: newChain)

                    setupRuntimeVersionSubscription(for: newChain, connection: connection)
                case let .update(updatedChain):
                    _ = try connectionPool.setupConnection(for: updatedChain)
                    _ = runtimeProviderPool.setupRuntimeProvider(for: updatedChain)
                case let .delete(chainId):
                    runtimeProviderPool.destroyRuntimeProvider(for: chainId)
                    clearRuntimeSubscription(for: chainId)
                }
            } catch {
                logger?.error("Unexpected error on handling chains update: \(error)")
            }
        }

        if isSetup {
            resolverWaiterIfNeeded()
        }
    }

    private func setupRuntimeVersionSubscription(for chain: ChainModel, connection: ChainConnection) {
        let subscription = specVersionSubscriptionFactory.createSubscription(
            for: chain.chainId,
            connection: connection
        )

        subscription.subscribe()

        runtimeVersionSubscriptions?[chain.chainId] = subscription
    }

    private func clearRuntimeSubscription(for chainId: ChainModel.Id) {
        if let subscription = runtimeVersionSubscriptions?[chainId] {
            subscription.unsubscribe()
        }

        runtimeVersionSubscriptions?[chainId] = nil
    }

    private func collectAvailableChains() -> Set<ChainModel.Id>? {
        runtimeVersionSubscriptions?.reduce(into: Set<String>()) { allKeys, keyValue in
            allKeys.insert(keyValue.key)
        }
    }

    private func resolverWaiterIfNeeded() {
        guard !waiters.isEmpty, let availableChains = collectAvailableChains() else {
            return
        }

        let waitersToResolver = waiters

        waiters = []

        waitersToResolver.forEach { waiterClosure in
            waiterClosure(availableChains)
        }
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

        return collectAvailableChains()
    }

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return connectionPool.getConnetion(for: chainId)
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return runtimeProviderPool.getRuntimeProvider(for: chainId)
    }

    func waitForSetupCompletion(with closure: @escaping ChainRegistrySetupClosure) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let availableChains = collectAvailableChains() {
            DispatchQueue.main.async {
                closure(availableChains)
            }

            return
        }

        waiters.append(closure)
    }

    func syncUp() {
        syncUpServices()
    }
}
