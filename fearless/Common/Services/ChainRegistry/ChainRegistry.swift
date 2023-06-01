import Foundation
import RobinHood
import FearlessUtils

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
    func performHotBoot()
    func performColdBoot()
    func subscribeToChians()
}

final class ChainRegistry {
    private let snapshotHotBootBuilder: SnapshotHotBootBuilderProtocol
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let connectionPool: ConnectionPoolProtocol
    private let chainSyncService: ChainSyncServiceProtocol
    private let runtimeSyncService: RuntimeSyncServiceProtocol
    private let chainsTypesSyncService: ChainsTypesSyncServiceProtocol
    private let chainProvider: StreamableProvider<ChainModel>
    private let specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol
    private let processingQueue = DispatchQueue(label: "jp.co.soramitsu.chain.registry")
    private let logger: LoggerProtocol?
    private let eventCenter: EventCenterProtocol
    private let networkIssuesCenter: NetworkIssuesCenterProtocol

    private var chains: [ChainModel] = []
    private var chainsTypesMap: [String: Data]?

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]

    private let mutex = NSLock()
    private lazy var readLock = ReaderWriterLock()

    init(
        snapshotHotBootBuilder: SnapshotHotBootBuilderProtocol,
        runtimeProviderPool: RuntimeProviderPoolProtocol,
        connectionPool: ConnectionPoolProtocol,
        chainSyncService: ChainSyncServiceProtocol,
        runtimeSyncService: RuntimeSyncServiceProtocol,
        chainsTypesSyncService: ChainsTypesSyncServiceProtocol,
        chainProvider: StreamableProvider<ChainModel>,
        specVersionSubscriptionFactory: SpecVersionSubscriptionFactoryProtocol,
        networkIssuesCenter: NetworkIssuesCenterProtocol,
        logger: LoggerProtocol? = nil,
        eventCenter: EventCenterProtocol
    ) {
        self.snapshotHotBootBuilder = snapshotHotBootBuilder
        self.runtimeProviderPool = runtimeProviderPool
        self.connectionPool = connectionPool
        self.chainSyncService = chainSyncService
        self.runtimeSyncService = runtimeSyncService
        self.chainsTypesSyncService = chainsTypesSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
        self.networkIssuesCenter = networkIssuesCenter
        self.logger = logger
        self.eventCenter = eventCenter
        self.eventCenter.add(observer: self, dispatchIn: .global())

        connectionPool.setDelegate(self)
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
                    let chainTypes = chainsTypesMap?[newChain.chainId]

                    runtimeProviderPool.setupRuntimeProvider(for: newChain, chainTypes: chainTypes)
                    runtimeSyncService.register(chain: newChain, with: connection)
                    setupRuntimeVersionSubscription(for: newChain, connection: connection)

                    chains.append(newChain)
                case let .update(updatedChain):
                    clearRuntimeSubscription(for: updatedChain.chainId)

                    let connection = try connectionPool.setupConnection(for: updatedChain)
                    let chainTypes = chainsTypesMap?[updatedChain.chainId]

                    runtimeProviderPool.setupRuntimeProvider(for: updatedChain, chainTypes: chainTypes)
                    setupRuntimeVersionSubscription(for: updatedChain, connection: connection)

                    chains = chains.filter { $0.chainId != updatedChain.chainId }
                    chains.append(updatedChain)

                case let .delete(chainId):
                    runtimeProviderPool.destroyRuntimeProvider(for: chainId)
                    clearRuntimeSubscription(for: chainId)

                    runtimeSyncService.unregister(chainId: chainId)

                    chains = chains.filter { $0.chainId != chainId }
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
        chainsTypesSyncService.syncUp()
    }
}

// MARK: - ChainRegistryProtocol

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        return Set(runtimeVersionSubscriptions.keys)
    }

    func performColdBoot() {
        subscribeToChians()
        syncUpServices()
    }

    func performHotBoot() {
        guard chains.isEmpty else { return }
        snapshotHotBootBuilder.startHotBoot()
    }

    func subscribeToChians() {
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

    func getConnection(for chainId: ChainModel.Id) -> ChainConnection? {
        readLock.concurrentlyRead { connectionPool.getConnection(for: chainId) }
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

// MARK: - ConnectionPoolDelegate

extension ChainRegistry: ConnectionPoolDelegate {
    func webSocketDidChangeState(url: URL, state: WebSocketEngine.State) {
        let failedChain = chains.first { chain in
            chain.nodes.first { node in
                node.url == url
            } != nil
        }

        guard let failedChain = failedChain else { return }

        switch state {
        case let .waitingReconnection(attempt: attempt):
            if attempt > 1 {
                connectionNeedsReconnect(for: failedChain, previusUrl: url, state: state)
            }
        default:
            break
        }
    }

    func connectionNeedsReconnect(for chain: ChainModel, previusUrl: URL, state: WebSocketEngine.State) {
        guard chain.selectedNode == nil else {
            return
        }

        do {
            _ = try connectionPool.setupConnection(for: chain, ignoredUrl: previusUrl)

            let event = ChainsUpdatedEvent(updatedChains: [chain])
            eventCenter.notify(with: event)
        } catch {
            logger?.error("\(chain.name) error: \(error.localizedDescription)")
            let reconnectedEvent = ChainReconnectingEvent(chain: chain, state: state)
            eventCenter.notify(with: reconnectedEvent)
        }
    }
}

// MARK: - EventVisitorProtocol

extension ChainRegistry: EventVisitorProtocol {
    func processRuntimeChainsTypesSyncCompleted(event: RuntimeChainsTypesSyncCompleted) {
        chainsTypesMap = event.versioningMap
    }
}
