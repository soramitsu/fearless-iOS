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
        let (provider, observable) = makeChainProvider()

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
        XCTAssertTrue(observable.waitUntilObserverAttached())

        XCTAssertTrue(observable.send([.insert(newItem: enabledOld)]))
        let firstConnection: ChainConnection = try waitForValue {
            guard
                registry.getChain(for: enabledOld.chainId)?.selectedNode == oldNode
            else {
                return nil
            }

            return registry.getConnection(for: enabledOld.chainId)
        }
        XCTAssertEqual(connectionFactory.requestedURLs, [[oldNode.url]])

        XCTAssertTrue(observable.send([.update(newItem: disabled)]))
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

        XCTAssertTrue(observable.send([.update(newItem: enabledNew)]))
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
        let (provider, observable) = makeChainProvider()
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
        XCTAssertTrue(observable.waitUntilObserverAttached())

        XCTAssertTrue(observable.send([.insert(newItem: oldChain)]))
        let firstURL: URL = try waitForValue {
            nodeFetching.requestedURLs.first
        }

        XCTAssertTrue(observable.send([.update(newItem: updatedChain)]))
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

    private func makeChainProvider()
        -> (StreamableProvider<ChainModel>, ChainRegistryTestObservable) {
        let repository = ChainRegistryTestRepository()
        let observable = ChainRegistryTestObservable()
        let source = fearless.EmptyStreamableSource<ChainModel>()

        let provider = StreamableProvider(
            source: AnyStreamableSource(source),
            repository: AnyDataProviderRepository(repository),
            observable: AnyDataProviderRepositoryObservable(observable),
            operationManager: OperationManager()
        )

        return (provider, observable)
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
        timeout: TimeInterval = 10,
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
        timeout: TimeInterval = 10,
        _ condition: () -> Bool
    ) throws {
        let _: Bool = try waitForValue(timeout: timeout) {
            condition() ? true : nil
        }
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

private final class ChainRegistryTestRepository:
    DataProviderRepositoryProtocol {
    typealias Model = ChainModel

    func fetchOperation(
        by _: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<ChainModel?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(
        with _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainModel]> {
        ClosureOperation { [] }
    }

    func saveOperation(
        _: @escaping () throws -> [ChainModel],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(
        _: @escaping () throws -> [ChainModel],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(
        _: @escaping () throws -> [ChainModel]
    ) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        ClosureOperation { 0 }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation { () }
    }
}

private final class ChainRegistryTestObservable:
    DataProviderRepositoryObservable {
    typealias Model = ChainModel

    private let condition = NSCondition()
    private weak var observer: AnyObject?
    private var deliveryQueue: DispatchQueue?
    private var updateBlock: (([DataProviderChange<ChainModel>]) -> Void)?

    func start(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func stop(completionBlock: @escaping (Error?) -> Void) {
        completionBlock(nil)
    }

    func addObserver(
        _ observer: AnyObject,
        deliverOn queue: DispatchQueue,
        executing updateBlock: @escaping ([DataProviderChange<ChainModel>]) -> Void
    ) {
        condition.lock()
        self.observer = observer
        deliveryQueue = queue
        self.updateBlock = updateBlock
        condition.broadcast()
        condition.unlock()
    }

    func removeObserver(_ observer: AnyObject) {
        condition.lock()
        if self.observer === observer {
            self.observer = nil
            deliveryQueue = nil
            updateBlock = nil
        }
        condition.unlock()
    }

    func waitUntilObserverAttached(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        condition.lock()
        defer { condition.unlock() }

        while observer == nil || deliveryQueue == nil || updateBlock == nil {
            guard condition.wait(until: deadline) else {
                return false
            }
        }

        return true
    }

    @discardableResult
    func send(_ changes: [DataProviderChange<ChainModel>]) -> Bool {
        condition.lock()
        let queue = deliveryQueue
        let block = updateBlock
        condition.unlock()

        guard let queue, let block else {
            return false
        }

        queue.async {
            block(changes)
        }

        return true
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
