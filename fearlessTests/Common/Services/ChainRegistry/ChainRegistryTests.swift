import Cuckoo
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import Web3
import XCTest
@testable import fearless

final class ChainRegistryTests: XCTestCase {
    func testDisabledThenReenabledChainDisconnectsAndUsesNewNode() throws {
        let storageFacade = SubstrateStorageTestFacade()
        let repository = ChainRepositoryFactory(
            storageFacade: storageFacade
        ).createRepository()
        let provider = makeChainProvider(
            storageFacade: storageFacade,
            repository: repository
        )

        let oldNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://old-node.example")),
            name: "Old",
            apikey: nil
        )
        let newNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "wss://new-node.example")),
            name: "New",
            apikey: nil
        )
        let enabledOld = makeChain(
            identifier: "lifecycle-chain",
            disabled: false,
            node: oldNode
        )
        let disabled = makeChain(
            identifier: enabledOld.chainId,
            disabled: true,
            node: oldNode
        )
        let enabledNew = makeChain(
            identifier: enabledOld.chainId,
            disabled: false,
            node: newNode
        )

        let connectionFactory = RecordingConnectionFactory()
        let connectionPool = ConnectionPool(
            connectionFactory: connectionFactory
        )
        let runtimeProviderPool = makeRuntimeProviderPool()
        let runtimeSyncService = makeRuntimeSyncService()
        let subscriptionFactory = makeSubscriptionFactory()
        let registry = ChainRegistry(
            snapshotHotBootBuilder: NoopSnapshotHotBootBuilder(),
            runtimeProviderPool: runtimeProviderPool,
            connectionPools: [connectionPool],
            chainSyncService: NoopChainSyncService(),
            runtimeSyncService: runtimeSyncService,
            chainsTypesSyncService: NoopChainsTypesSyncService(),
            chainProvider: provider,
            specVersionSubscriptionFactory: subscriptionFactory,
            networkIssuesCenter: NoopNetworkIssuesCenter(),
            eventCenter: NoopEventCenter()
        )
        registry.subscribeToChains()

        try save(enabledOld, in: repository)
        let firstConnection: ChainConnection = try waitForValue {
            guard
                registry.getChain(for: enabledOld.chainId)?.selectedNode == oldNode
            else {
                return nil
            }

            return registry.getConnection(for: enabledOld.chainId)
        }
        XCTAssertEqual(connectionFactory.requestedURLs, [[oldNode.url]])

        try save(disabled, in: repository)
        try waitForCondition {
            registry.getChain(for: enabledOld.chainId) == nil &&
                registry.getConnection(for: enabledOld.chainId) == nil
        }
        XCTAssertNil(registry.getConnection(for: enabledOld.chainId))
        XCTAssertEqual(
            (firstConnection as? MockConnection)?.disconnectCallCount,
            1
        )
        XCTAssertEqual(connectionFactory.requestedURLs, [[oldNode.url]])

        try save(enabledNew, in: repository)
        let secondConnection: ChainConnection = try waitForValue {
            guard
                registry.getChain(for: enabledOld.chainId)?.selectedNode == newNode
            else {
                return nil
            }

            return registry.getConnection(for: enabledOld.chainId)
        }
        XCTAssertFalse(firstConnection === secondConnection)
        XCTAssertEqual(
            connectionFactory.requestedURLs,
            [[oldNode.url], [newNode.url]]
        )
        XCTAssertEqual(
            (firstConnection as? MockConnection)?.disconnectCallCount,
            1
        )
        XCTAssertEqual(
            (secondConnection as? MockConnection)?.disconnectCallCount,
            0
        )

        provider.removeObserver(registry)
    }

    func testUpdatedEthereumChainUsesReplacementNodeImmediately() throws {
        let storageFacade = SubstrateStorageTestFacade()
        let repository = ChainRepositoryFactory(
            storageFacade: storageFacade
        ).createRepository()
        let provider = makeChainProvider(
            storageFacade: storageFacade,
            repository: repository
        )
        let oldNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "https://old-rpc.example")),
            name: "Old Ethereum RPC",
            apikey: nil
        )
        let newNode = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "https://new-rpc.example")),
            name: "New Ethereum RPC",
            apikey: nil
        )
        let chainId = "ethereum-lifecycle-chain"
        let oldChain = makeEthereumChain(
            identifier: chainId,
            node: oldNode
        )
        let updatedChain = makeEthereumChain(
            identifier: chainId,
            node: newNode
        )
        let nodeFetching = RecordingEthereumNodeFetching()
        let ethereumPool = EthereumConnectionPool(
            nodeFetching: nodeFetching
        )
        let registry = ChainRegistry(
            snapshotHotBootBuilder: NoopSnapshotHotBootBuilder(),
            runtimeProviderPool: makeRuntimeProviderPool(),
            connectionPools: [ethereumPool],
            chainSyncService: NoopChainSyncService(),
            runtimeSyncService: makeRuntimeSyncService(),
            chainsTypesSyncService: NoopChainsTypesSyncService(),
            chainProvider: provider,
            specVersionSubscriptionFactory: makeSubscriptionFactory(),
            networkIssuesCenter: NoopNetworkIssuesCenter(),
            eventCenter: NoopEventCenter()
        )
        registry.subscribeToChains()

        try save(oldChain, in: repository)
        let firstURL: URL = try waitForValue {
            nodeFetching.requestedURLs.first
        }

        try save(updatedChain, in: repository)
        let secondURL: URL = try waitForValue {
            let urls = nodeFetching.requestedURLs
            return urls.count >= 2 ? urls.last : nil
        }

        XCTAssertEqual(firstURL, oldNode.url)
        XCTAssertEqual(secondURL, newNode.url)
        XCTAssertEqual(
            nodeFetching.requestedURLs,
            [oldNode.url, newNode.url]
        )
        XCTAssertNotNil(
            registry.getEthereumConnection(for: chainId)
        )
        XCTAssertEqual(
            registry.getChain(for: chainId)?.selectedNode,
            newNode
        )

        provider.removeObserver(registry)
    }

    private func makeChainProvider(
        storageFacade: SubstrateStorageTestFacade,
        repository: CoreDataRepository<ChainModel, CDChain>
    ) -> StreamableProvider<ChainModel> {
        let observable = CoreDataContextObservable(
            service: storageFacade.databaseService,
            mapper: repository.dataMapper,
            predicate: { _ in true }
        )
        observable.start { error in
            XCTAssertNil(error)
        }
        let source = fearless.EmptyStreamableSource<ChainModel>()

        return StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: fearless.OperationManagerFacade.sharedManager
        )
    }

    private func makeChain(
        identifier: String,
        disabled: Bool,
        node: ChainNodeModel
    ) -> ChainModel {
        ChainModel(
            rank: 1,
            disabled: disabled,
            chainId: identifier,
            paraId: nil,
            name: "Lifecycle",
            xcm: nil,
            nodes: [node],
            addressPrefix: 42,
            icon: nil,
            selectedNode: node,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func makeEthereumChain(
        identifier: String,
        node: ChainNodeModel
    ) -> ChainModel {
        ChainModel(
            rank: 1,
            disabled: false,
            chainId: identifier,
            paraId: nil,
            name: "Ethereum Lifecycle",
            xcm: nil,
            nodes: [node],
            addressPrefix: 0,
            icon: nil,
            options: [.ethereum],
            selectedNode: node,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

    private func waitForValue<T>(
        timeout: TimeInterval = 2,
        _ valueProvider: () -> T?
    ) throws -> T {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if let value = valueProvider() {
                return value
            }

            RunLoop.current.run(
                until: Date().addingTimeInterval(0.01)
            )
        }

        throw ChainRegistryTestError.timeout
    }

    private func waitForCondition(
        timeout: TimeInterval = 2,
        _ condition: () -> Bool
    ) throws {
        let _: Bool = try waitForValue(timeout: timeout) {
            condition() ? true : nil
        }
    }

    private func save(
        _ chain: ChainModel,
        in repository: CoreDataRepository<ChainModel, CDChain>
    ) throws {
        let operation = repository.saveOperation({ [chain] }, { [] })
        OperationQueue().addOperations([operation], waitUntilFinished: true)
        let _: Void = try XCTUnwrap(operation.result).get()
    }

    private func makeRuntimeProviderPool() -> MockRuntimeProviderPoolProtocol {
        let pool = MockRuntimeProviderPoolProtocol()
        let provider = NoopRuntimeProvider()
        stub(pool) { stub in
            stub.setupRuntimeProvider(
                for: any(),
                chainTypes: any()
            ).thenReturn(provider)
            stub.destroyRuntimeProvider(for: any()).thenDoNothing()
        }
        return pool
    }

    private func makeRuntimeSyncService() -> MockRuntimeSyncServiceProtocol {
        let service = MockRuntimeSyncServiceProtocol()
        stub(service) { stub in
            stub.register(chain: any(), with: any()).thenDoNothing()
            stub.unregister(chainId: any()).thenDoNothing()
        }
        return service
    }

    private func makeSubscriptionFactory()
        -> MockSpecVersionSubscriptionFactoryProtocol {
        let factory = MockSpecVersionSubscriptionFactoryProtocol()
        let subscription = MockSpecVersionSubscriptionProtocol()
        stub(subscription) { stub in
            stub.subscribe().thenDoNothing()
            stub.unsubscribe().thenDoNothing()
        }
        stub(factory) { stub in
            stub.createSubscription(
                for: any(),
                connection: any()
            ).thenReturn(subscription)
        }
        return factory
    }
}

private enum ChainRegistryTestError: Error {
    case timeout
}

private final class RecordingEthereumNodeFetching:
    EthereumNodeFetchingProtocol {
    private let lock = NSLock()
    private var urls: [URL] = []

    var requestedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }

        return urls
    }

    func getNode(for chain: ChainModel) throws -> Web3.Eth {
        if let selectedURL = chain.selectedNode?.url {
            lock.lock()
            urls.append(selectedURL)
            lock.unlock()
        }

        return try EthereumNodeFetching().getNode(for: chain)
    }
}

private final class RecordingConnectionFactory: ConnectionFactoryProtocol {
    private let lock = NSLock()
    private var connections: [MockConnection] = []
    private var urls: [[URL]] = []

    var requestedURLs: [[URL]] {
        lock.lock()
        defer { lock.unlock() }
        return urls
    }

    func createConnection(
        connectionName: String?,
        for urls: [URL],
        delegate _: WebSocketEngineDelegate
    ) throws -> ChainConnection {
        let connection = MockConnection()
        connection.connectionName = connectionName
        connection.url = urls.first

        lock.lock()
        self.urls.append(urls)
        connections.append(connection)
        lock.unlock()

        return connection
    }
}

private final class NoopSnapshotHotBootBuilder:
    SnapshotHotBootBuilderProtocol {
    func startHotBoot() {}
}

private final class NoopChainSyncService: ChainSyncServiceProtocol {
    func syncUp() {}
}

private final class NoopChainsTypesSyncService:
    ChainsTypesSyncServiceProtocol {
    func syncUp() {}
}

private final class NoopNetworkIssuesCenter: NetworkIssuesCenterProtocol {
    func addIssuesListener(
        _: NetworkIssuesCenterListener,
        getExisting _: Bool
    ) {}

    func removeIssuesListener(_: NetworkIssuesCenterListener) {}

    func forceNotify() {}
}

private final class NoopEventCenter: EventCenterProtocol {
    func notify(with _: EventProtocol) {}

    func add(
        observer _: EventVisitorProtocol,
        dispatchIn _: DispatchQueue?
    ) {}

    func remove(observer _: EventVisitorProtocol) {}
}

private final class NoopRuntimeProvider: RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?

    func setup() {}

    func setupHot() {}

    func cleanup() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw SSFRuntimeCodingService.RuntimeProviderError
            .providerUnavailable
    }

    func fetchCoderFactoryOperation()
        -> BaseOperation<RuntimeCoderFactoryProtocol> {
        BaseOperation()
    }

    func fetchCoderFactory() async throws
        -> RuntimeCoderFactoryProtocol {
        throw SSFRuntimeCodingService.RuntimeProviderError
            .providerUnavailable
    }
}
