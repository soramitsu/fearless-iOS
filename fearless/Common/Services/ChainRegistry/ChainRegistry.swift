import Foundation
import RobinHood
import SSFUtils
import SSFModels

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }
    var chainsTypesMap: [String: Data] { get }

    func resetConnection(for chainId: ChainModel.Id)
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
    var chainsTypesMap: [String: Data] = [:]

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]

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
        guard !changes.isEmpty else {
            return
        }

        readLock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else {
                return
            }

            changes.forEach { change in
                do {
                    switch change {
                    case let .insert(newChain):
                        let connection = try strongSelf.connectionPool.setupConnection(for: newChain)
                        let chainTypes = strongSelf.chainsTypesMap[newChain.chainId]

                        strongSelf.runtimeProviderPool.setupRuntimeProvider(for: newChain, chainTypes: chainTypes)
                        strongSelf.runtimeSyncService.register(chain: newChain, with: connection)
                        strongSelf.setupRuntimeVersionSubscription(for: newChain, connection: connection)

                        strongSelf.chains.append(newChain)
                    case let .update(updatedChain):
                        strongSelf.clearRuntimeSubscription(for: updatedChain.chainId)

                        let connection = try strongSelf.connectionPool.setupConnection(for: updatedChain)
                        let chainTypes = strongSelf.chainsTypesMap[updatedChain.chainId]

                        strongSelf.runtimeProviderPool.setupRuntimeProvider(for: updatedChain, chainTypes: chainTypes)
                        strongSelf.setupRuntimeVersionSubscription(for: updatedChain, connection: connection)

                        strongSelf.chains = strongSelf.chains.filter { $0.chainId != updatedChain.chainId }
                        strongSelf.chains.append(updatedChain)

                    case let .delete(chainId):
                        strongSelf.runtimeProviderPool.destroyRuntimeProvider(for: chainId)
                        strongSelf.clearRuntimeSubscription(for: chainId)

                        strongSelf.runtimeSyncService.unregister(chainId: chainId)

                        strongSelf.chains = strongSelf.chains.filter { $0.chainId != chainId }
                    }
                } catch {
                    strongSelf.logger?.error("Unexpected error on handling chains update: \(error)")
                }
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
        readLock.concurrentlyRead { Set(runtimeVersionSubscriptions.keys) }
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
        readLock.concurrentlyRead { runtimeProviderPool.getRuntimeProvider(for: chainId) }
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
        DispatchQueue.global().async {
            self.syncUpServices()
        }
    }

    func resetConnection(for chainId: ChainModel.Id) {
        connectionPool.resetConnection(for: chainId)
    }
}

// MARK: - ConnectionPoolDelegate

extension ChainRegistry: ConnectionPoolDelegate {
    func webSocketDidChangeState(url: URL, state: WebSocketEngine.State) {
        guard let changedStateChain = chains.first(where: { chain in
            chain.nodes.first { node in
                node.url == url
            } != nil
        }) else {
            return
        }

        let reconnectedEvent = ChainReconnectingEvent(chain: changedStateChain, state: state)
        eventCenter.notify(with: reconnectedEvent)

        switch state {
        case let .waitingReconnection(attempt: attempt):
            if attempt > NetworkConstants.websocketReconnectAttemptsLimit {
                connectionNeedsReconnect(for: changedStateChain, previusUrl: url, state: state)
            }
        default:
            break
        }
    }

    func connectionNeedsReconnect(for chain: ChainModel, previusUrl: URL, state _: WebSocketEngine.State) {
        guard chain.selectedNode == nil else {
            return
        }

        do {
            _ = try connectionPool.setupConnection(for: chain, ignoredUrl: previusUrl)

            let event = ChainsUpdatedEvent(updatedChains: [chain])
            eventCenter.notify(with: event)
        } catch {
            logger?.error("\(chain.name) error: \(error.localizedDescription)")
            let reconnectedEvent = ChainReconnectingEvent(chain: chain, state: .notConnected)
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
