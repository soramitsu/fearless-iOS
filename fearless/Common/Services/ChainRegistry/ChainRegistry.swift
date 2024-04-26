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
    func subscribeToWallets()
}

final class ChainRegistry {
    private var currentWallet: MetaAccountModel?

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
    private let walletStreamableProvider: StreamableProvider<ManagedMetaAccountModel>

    private var chains: [ChainModel] = []
    var chainsTypesMap: [String: Data] = [:]

    private(set) var runtimeVersionSubscriptions: [ChainModel.Id: SpecVersionSubscriptionProtocol] = [:]

    private lazy var readLock = ReaderWriterLock()

    private var substrateConnectionPool: ConnectionPool? {
        connectionPools.first(where: { $0 is ConnectionPool }) as? ConnectionPool
    }

    private var ethereumConnectionPool: EthereumConnectionPool? {
        connectionPools.first(where: { $0 is EthereumConnectionPool }) as? EthereumConnectionPool
    }

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
        eventCenter: EventCenterProtocol,
        walletStreamableProvider: StreamableProvider<ManagedMetaAccountModel>
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
        self.walletStreamableProvider = walletStreamableProvider
        self.eventCenter.add(observer: self, dispatchIn: .global())

        connectionPools.forEach { $0.setDelegate(self) }
    }

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
                        guard self.shouldSetConnetion(newChain) else {
                            self.resetConnection(for: newChain.chainId)
                            return
                        }

                        if newChain.isEthereum {
                            try self.handleNewEthereumChain(newChain: newChain)
                        } else {
                            try self.handleNewSubstrateChain(newChain: newChain)
                        }
                    case let .update(updatedChain):
                        guard self.shouldSetConnetion(updatedChain) else {
                            self.resetConnection(for: updatedChain.chainId)
                            return
                        }

                        if updatedChain.isEthereum {
                            try self.handleUpdatedEthereumChain(updatedChain: updatedChain)
                        } else {
                            try self.handleUpdatedSubstrateChain(updatedChain: updatedChain)
                        }
                    case let .delete(chainId):
                        self.runtimeProviderPool.destroyRuntimeProvider(for: chainId)
                        self.clearRuntimeSubscription(for: chainId)

                        self.runtimeSyncService.unregister(chainId: chainId)

                        self.chains = self.chains.filter { $0.chainId != chainId }
                    }
                } catch {
                    self.logger?.error("Unexpected error on handling chains update: \(error)")
                }
            }

            self.eventCenter.notify(with: ChainsSetupCompleted())
        }
    }

    private func handleWallet(_ changes: [DataProviderChange<ManagedMetaAccountModel>]) {
        guard changes.isNotEmpty else {
            subscribeToChians()
            return
        }

        changes.forEach { change in
            switch change {
            case let .insert(newWallet):
                updateCurrentWallet(newWallet.info)
            case let .update(updatedWallet):
                guard updatedWallet.isSelected else {
                    return
                }
                updateCurrentWallet(updatedWallet.info)
            case .delete:
                break
            }
        }
    }

    private func shouldSetConnetion(_ chain: ChainModel) -> Bool {
        let hasVisibleAsset = hasVisibleAsset(chain, wallet: currentWallet)
        let isRequaredConnection = isChainWithRequaredConnection(chain)

        let shouldSetConnection = [
            hasVisibleAsset,
            isRequaredConnection
        ].contains(true)
        return shouldSetConnection
    }

    private func isChainWithRequaredConnection(_ chain: ChainModel) -> Bool {
        let isChainlinkProvider = chain.options?.contains(.chainlinkProvider)
        let hasPoolStaking = chain.options?.contains(.poolStaking)
        let hasRelaychainStaking = chain.assets.compactMap { $0.staking }.contains(where: { $0.isRelaychain })
        let hasParachainStaking = chain.assets.compactMap { $0.staking }.contains(where: { $0.isParachain })

        let isRequared = [
            isChainlinkProvider,
            hasPoolStaking,
            hasRelaychainStaking,
            hasParachainStaking
        ]
        .compactMap { $0 }
        .contains(true)

        return isRequared
    }

    private func hasVisibleAsset(_ chain: ChainModel, wallet: MetaAccountModel?) -> Bool {
        guard let wallet, wallet.assetsVisibility.isNotEmpty else {
            return true
        }
        let chainAssetIds = chain.chainAssets.map { $0.identifier }
        let hasVisible = wallet.assetsVisibility.contains(where: { chainAssetIds.contains($0.assetId) && !$0.hidden })
        return hasVisible
    }

    private func updateCurrentWallet(_ wallet: MetaAccountModel) {
        if currentWallet?.assetsVisibility != wallet.assetsVisibility {
            currentWallet = wallet
            chainProvider.removeObserver(self)
            subscribeToChians()
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
        chains.append(newChain)
        _ = try ethereumConnectionPool.setupConnection(for: newChain)
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
        _ = try ethereumConnectionPool.setupConnection(for: updatedChain)
        chains = chains.filter { $0.chainId != updatedChain.chainId }
        chains.append(updatedChain)
    }

    private func handleDeletedSubstrateChain(chainId: ChainModel.Id) throws {
        runtimeProviderPool.destroyRuntimeProvider(for: chainId)
        clearRuntimeSubscription(for: chainId)

        runtimeSyncService.unregister(chainId: chainId)

        chains = chains.filter { $0.chainId != chainId }
    }

    private func handleDeletedEthereumChain(chainId: ChainModel.Id) throws {
        chains = chains.filter { $0.chainId != chainId }
    }

    private func resetSubstrateConnection(for chainId: ChainModel.Id) {
        guard let substrateConnectionPool = self.substrateConnectionPool else {
            return
        }

        substrateConnectionPool.resetConnection(for: chainId)
    }

    private func resetEthereumConnection(for _: ChainModel.Id) {
        // TODO: Reset eth connection
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
        subscribeToWallets()
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

    func subscribeToWallets() {
        let updateClosure: ([DataProviderChange<ManagedMetaAccountModel>]) -> Void = { [weak self] changes in
            self?.handleWallet(changes)
        }

        let failureClosure: (Error) -> Void = { [weak self] error in
            self?.logger?.error("Unexpected error chains listener setup: \(error)")
        }

        let options = StreamableProviderObserverOptions(
            alwaysNotifyOnRefresh: false,
            waitsInProgressSyncOnAdd: false,
            refreshWhenEmpty: false
        )

        walletStreamableProvider.addObserver(
            self,
            deliverOn: DispatchQueue.global(),
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
        let connection = getConnection(for: chain.chainId)
        guard let connection else {
            throw ChainRegistryError.connectionUnavailable
        }

        return connection
    }

    func getEthereumConnection(for chain: SSFModels.ChainModel) throws -> SSFChainConnection.Web3EthConnection {
        let connection = getEthereumConnection(for: chain.chainId)
        guard let connection else {
            throw ChainRegistryError.connectionUnavailable
        }
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
        guard let runtimeSnapshot = runtimeService.snapshot else {
            throw ChainRegistryError.runtimeMetadaUnavailable
        }
        return runtimeSnapshot
    }
}
