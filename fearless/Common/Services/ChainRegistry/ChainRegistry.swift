import Foundation
import RobinHood
import SSFUtils
import SSFModels
import Web3

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
    func getEthereumConnection(for chainId: ChainModel.Id) -> Web3.Eth?
    func chainsUnsubscribe(_ target: AnyObject)
    func syncUp()
    func performHotBoot()
    func performColdBoot()
    func subscribeToChians()
}

final class ChainRegistry {
    private let snapshotHotBootBuilder: SnapshotHotBootBuilderProtocol
    private let runtimeProviderPool: RuntimeProviderPoolProtocol
    private let connectionPools: [any ConnectionPoolProtocol]
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
        connectionPools: [any ConnectionPoolProtocol],
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
        self.connectionPools = connectionPools
        self.chainSyncService = chainSyncService
        self.runtimeSyncService = runtimeSyncService
        self.chainsTypesSyncService = chainsTypesSyncService
        self.chainProvider = chainProvider
        self.specVersionSubscriptionFactory = specVersionSubscriptionFactory
        self.networkIssuesCenter = networkIssuesCenter
        self.logger = logger
        self.eventCenter = eventCenter
        self.eventCenter.add(observer: self, dispatchIn: .global())

        connectionPools.forEach { $0.setDelegate(self) }
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
                        if newChain.isEthereum {
                            try strongSelf.handleNewEthereumChain(newChain: newChain)
                        } else {
                            try strongSelf.handleNewSubstrateChain(newChain: newChain)
                        }
                    case let .update(updatedChain):
                        if updatedChain.isEthereum {
                            try strongSelf.handleUpdatedEthereumChain(updatedChain: updatedChain)
                        } else {
                            try strongSelf.handleUpdatedSubstrateChain(updatedChain: updatedChain)
                        }
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

    private var substrateConnectionPool: ConnectionPool? {
        connectionPools.first(where: { $0 is ConnectionPool }) as? ConnectionPool
    }

    private var ethereumConnectionPool: EthereumConnectionPool? {
        connectionPools.first(where: { $0 is EthereumConnectionPool }) as? EthereumConnectionPool
    }

    private func handleNewSubstrateChain(newChain: ChainModel) throws {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        let connection = try substrateConnectionPool.setupConnection(for: newChain)
        let chainTypes = chainsTypesMap[newChain.chainId]

        runtimeProviderPool.setupRuntimeProvider(for: newChain, chainTypes: chainTypes)
        runtimeSyncService.register(chain: newChain, with: connection)
        setupRuntimeVersionSubscription(for: newChain, connection: connection)

        chains.append(newChain)
    }

    private func handleNewEthereumChain(newChain: ChainModel) throws {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            return
        }

        let connection = try ethereumConnectionPool.setupConnection(for: newChain)

        chains.append(newChain)
    }

    private func handleUpdatedSubstrateChain(updatedChain: ChainModel) throws {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        clearRuntimeSubscription(for: updatedChain.chainId)

        let connection = try substrateConnectionPool.setupConnection(for: updatedChain)
        let chainTypes = chainsTypesMap[updatedChain.chainId]

        runtimeProviderPool.setupRuntimeProvider(for: updatedChain, chainTypes: chainTypes)
        setupRuntimeVersionSubscription(for: updatedChain, connection: connection)

        chains = chains.filter { $0.chainId != updatedChain.chainId }
        chains.append(updatedChain)
    }

    private func handleUpdatedEthereumChain(updatedChain: ChainModel) throws {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            return
        }

        let connection = try ethereumConnectionPool.setupConnection(for: updatedChain)

        chains = chains.filter { $0.chainId != updatedChain.chainId }
        chains.append(updatedChain)
    }

    private func handleDeletedSubstrateChain(chainId: ChainModel.Id) throws {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        runtimeProviderPool.destroyRuntimeProvider(for: chainId)
        clearRuntimeSubscription(for: chainId)

        runtimeSyncService.unregister(chainId: chainId)

        chains = chains.filter { $0.chainId != chainId }
    }

    private func handleDeletedEthereumChain(chainId: ChainModel.Id) throws {
        chains = chains.filter { $0.chainId != chainId }
    }

    func resetSubstrateConnection(for chain: ChainModel) {
        guard let chain = chains.first(where: { $0.chainId == chain.chainId }),
              let substrateConnectionPool = self.substrateConnectionPool
        else {
            return
        }

        substrateConnectionPool.resetConnection(for: chain.chainId)
    }

    func resetEthereumConnection(for chain: ChainModel) {
        guard let chain = chains.first(where: { $0.chainId == chain.chainId }) else {
            return
        }

        // TODO: Reset eth connection
    }
}

// MARK: - ChainRegistryProtocol

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        readLock.concurrentlyRead { Set(runtimeVersionSubscriptions.keys + chains.filter { $0.isEthereum }.map { $0.chainId }) }
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
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return nil
        }

        return readLock.concurrentlyRead { substrateConnectionPool.getConnection(for: chainId) }
    }

    func getEthereumConnection(for chainId: ChainModel.Id) -> Web3.Eth? {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            return nil
        }

        return ethereumConnectionPool.getConnection(for: chainId)
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
        guard let chain = chains.first(where: { $0.chainId == chainId }) else {
            return
        }

        if chain.isEthereum {
            resetEthereumConnection(for: chain)
        } else {
            resetSubstrateConnection(for: chain)
        }
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

        if case .connected = state {
            let reconnectedEvent = ChainReconnectingEvent(chain: changedStateChain, state: state)
            eventCenter.notify(with: reconnectedEvent)
        }

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
            if chain.isEthereum {
                // TODO: Ethereum reconnect
            } else {
                _ = try substrateConnectionPool?.setupConnection(for: chain, ignoredUrl: previusUrl)
            }

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
