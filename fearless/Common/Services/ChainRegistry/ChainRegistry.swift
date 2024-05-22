import Foundation
import RobinHood
import SSFUtils
import SSFModels
import Web3
import SSFChainRegistry
import SSFRuntimeCodingService
import SSFChainConnection

protocol ChainRegistryProtocol: AnyObject {
    var availableChainIds: Set<ChainModel.Id>? { get }
    var availableChains: [ChainModel] { get }
    var chainsTypesMap: [String: Data] { get }

    func resetConnection(for chainId: ChainModel.Id)
    func retryConnection(for chainId: ChainModel.Id)
    func getConnection(for chainId: ChainModel.Id) -> ChainConnection?
    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol?
    func getChain(for chainId: ChainModel.Id) -> ChainModel?
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
    private lazy var readLock = ReaderWriterLock()

    private var substrateConnectionPool: ConnectionPool? {
        connectionPools.first(where: { $0 is ConnectionPool }) as? ConnectionPool
    }

    private var ethereumConnectionPool: EthereumConnectionPool? {
        connectionPools.first(where: { $0 is EthereumConnectionPool }) as? EthereumConnectionPool
    }

    // MARK: - State

    private var chains: [ChainModel] = []
    private(set) var chainsTypesMap: [String: Data] = [:]
    private var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]

    // MARK: - Constructor

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

    // MARK: - Private handle subscription methods

    private func handleChainModel(_ changes: [DataProviderChange<ChainModel>]) {
        guard !changes.isEmpty else {
            return
        }

        readLock.exclusivelyWrite { [weak self] in
            guard let self else {
                return
            }

            changes.forEach { change in
                do {
                    switch change {
                    case let .insert(newChain):
                        try self.handleInsert(newChain)
                    case let .update(updatedChain):
                        try self.handleUpdate(updatedChain)
                    case let .delete(chainId):
                        self.handleDelete(chainId)
                    }
                } catch {
                    self.logger?.error("Unexpected error on handling chains update: \(error)")
                }
            }

            self.eventCenter.notify(with: ChainsSetupCompleted())
        }
    }

    // MARK: - Private DataProviderChange handle methods

    private func handleInsert(_ chain: ChainModel) throws {
        if chain.isEthereum {
            try handleNewEthereumChain(newChain: chain)
        } else {
            try handleNewSubstrateChain(newChain: chain)
        }
    }

    private func handleUpdate(_ chain: ChainModel) throws {
        if chain.isEthereum {
            try handleUpdatedEthereumChain(updatedChain: chain)
        } else {
            try handleUpdatedSubstrateChain(updatedChain: chain)
        }
    }

    private func handleDelete(_ chainId: ChainModel.Id) {
        guard let removedChain = chains.first(where: { $0.chainId == chainId }) else {
            return
        }

        if removedChain.isEthereum {
            handleDeletedEthereumChain(chainId: chainId)
        } else {
            handleDeletedSubstrateChain(chainId: chainId)
        }
    }

    // MARK: - Private substrate methods

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

    private func handleDeletedSubstrateChain(chainId: ChainModel.Id) {
        runtimeProviderPool.destroyRuntimeProvider(for: chainId)
        clearRuntimeSubscription(for: chainId)
        runtimeSyncService.unregister(chainId: chainId)
        chains = chains.filter { $0.chainId != chainId }
    }

    private func resetSubstrateConnection(for chainId: ChainModel.Id) {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        substrateConnectionPool.resetConnection(for: chainId)
    }

    // MARK: - Private ethereum methods

    private func handleNewEthereumChain(newChain: ChainModel) throws {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            return
        }
        chains.append(newChain)
        _ = try ethereumConnectionPool.setupConnection(for: newChain)
    }

    private func handleUpdatedEthereumChain(updatedChain: ChainModel) throws {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            return
        }
        _ = try ethereumConnectionPool.setupConnection(for: updatedChain)
        chains = chains.filter { $0.chainId != updatedChain.chainId }
        chains.append(updatedChain)
    }

    private func handleDeletedEthereumChain(chainId: ChainModel.Id) {
        chains = chains.filter { $0.chainId != chainId }
    }

    private func resetEthereumConnection(for _: ChainModel.Id) {
        // TODO: Reset eth connection
    }

    // MARK: - Private others methods

    private func syncUpServices() {
        chainSyncService.syncUp()
        chainsTypesSyncService.syncUp()
    }
}

// MARK: - ChainRegistryProtocol

extension ChainRegistry: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? {
        readLock.concurrentlyRead { Set(runtimeVersionSubscriptions.keys + chains.filter { $0.isEthereum }.map { $0.chainId }) }
    }

    var availableChains: [ChainModel] {
        readLock.concurrentlyRead {
            chains
        }
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
            self?.handleChainModel(changes)
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
        readLock.concurrentlyRead {
            guard
                let ethereumConnectionPool = self.ethereumConnectionPool,
                let chain = chains.first(where: { $0.chainId == chainId })
            else {
                return nil
            }

            return try? ethereumConnectionPool.setupConnection(for: chain)
        }
    }

    func getChain(for chainId: ChainModel.Id) -> ChainModel? {
        readLock.concurrentlyRead { chains.first(where: { $0.chainId == chainId }) }
    }

    func getRuntimeProvider(for chainId: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtimeProviderPool.getRuntimeProvider(for: chainId)
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
            resetEthereumConnection(for: chain.chainId)
        } else {
            resetSubstrateConnection(for: chain.chainId)
        }
    }

    func retryConnection(for chainId: ChainModel.Id) {
        guard
            let chain = chains.first(where: { $0.chainId == chainId }),
            let currentConnection = getConnection(for: chainId),
            let currentURL = currentConnection.url
        else {
            return
        }
        connectionNeedsReconnect(for: chain, previusUrl: currentURL)
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
                connectionNeedsReconnect(for: changedStateChain, previusUrl: url)
            }
        case .notConnected:
            connectionNeedsReconnect(for: changedStateChain, previusUrl: url)
        default:
            break
        }
    }

    func connectionNeedsReconnect(for chain: ChainModel, previusUrl: URL) {
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

// MARK: - SSF ChainRegistryProtocol adoptation

extension ChainRegistry: SSFChainRegistry.ChainRegistryProtocol {
    func getRuntimeProvider(
        chainId: SSFModels.ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: SSFModels.RuntimeMetadataItemProtocol?
    ) async throws -> SSFRuntimeCodingService.RuntimeProviderProtocol {
        let runtimeProvider = readLock.concurrentlyRead { runtimeProviderPool.getRuntimeProvider(for: chainId) }
        guard let runtimeProvider else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }
        return runtimeProvider
    }

    func getSubstrateConnection(for chain: SSFModels.ChainModel) throws -> SSFChainConnection.SubstrateConnection {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            throw ChainRegistryError.connectionUnavailable
        }
        let connection = try substrateConnectionPool.setupConnection(for: chain)
        return connection
    }

    func getEthereumConnection(for chain: SSFModels.ChainModel) throws -> SSFChainConnection.Web3EthConnection {
        guard let ethereumConnectionPool = self.ethereumConnectionPool else {
            throw ChainRegistryError.connectionUnavailable
        }
        let connection = try ethereumConnectionPool.setupConnection(for: chain)
        return connection
    }

    func getChain(for chainId: SSFModels.ChainModel.Id) async throws -> SSFModels.ChainModel {
        let chain = readLock.concurrentlyRead { chains.first(where: { $0.chainId == chainId }) }

        guard let chain else {
            throw ChainRegistryError.connectionUnavailable
        }

        return chain
    }

    func getChains() async throws -> [SSFModels.ChainModel] {
        availableChains
    }

    func getReadySnapshot(
        chainId: SSFModels.ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: SSFModels.RuntimeMetadataItemProtocol?
    ) async throws -> SSFRuntimeCodingService.RuntimeSnapshot {
        let runtimeService = try await getRuntimeProvider(chainId: chainId, usedRuntimePaths: [:], runtimeItem: nil)
        runtimeService.setup()
        let runtimeSnapshot = try await runtimeService.readySnapshot()
        return runtimeSnapshot
    }
}
