import Cuckoo
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import Web3
import XCTest
@testable import class SSFChainConnection.NetworkIssuesCenterImpl
import protocol SSFChainConnection.ConnectionIssuesCenterListener
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

    func getNode(for chain: ChainModel, url: URL) throws -> Web3.Eth {
        lock.lock()
        urls.append(url)
        lock.unlock()

        return try EthereumNodeFetching().getNode(for: chain, url: url)
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

final class IssuesCenterListenerRemovalTests: XCTestCase {
    func testNativeRemovalUnsubscribesEveryRegistrationAndPreservesOtherListeners() {
        let center = NetworkIssuesCenterImpl.shared
        let removed = NativeIssuesListenerSpy()
        let retained = NativeIssuesListenerSpy()
        defer {
            center.removeIssuesListener(removed)
            center.removeIssuesListener(retained)
        }
        center.addIssuesListener(removed, getExisting: false)
        center.addIssuesListener(removed, getExisting: false)
        center.addIssuesListener(retained, getExisting: false)
        center.forceNotify()
        XCTAssertEqual(removed.notificationCount, 2)
        XCTAssertEqual(retained.notificationCount, 1)

        center.removeIssuesListener(removed)
        center.removeIssuesListener(removed)
        center.forceNotify()
        XCTAssertEqual(removed.notificationCount, 2)
        XCTAssertEqual(retained.notificationCount, 2)
    }

    func testAppNetworkRemovalUnsubscribesEveryRegistrationAndPreservesOtherListeners() {
        let center = NetworkIssuesCenter.shared
        let removed = NetworkIssuesListenerSpy()
        let retained = NetworkIssuesListenerSpy()
        defer {
            center.removeIssuesListener(removed)
            center.removeIssuesListener(retained)
        }
        center.addIssuesListener(removed, getExisting: false)
        center.addIssuesListener(removed, getExisting: false)
        center.addIssuesListener(retained, getExisting: false)
        center.forceNotify()
        XCTAssertEqual(removed.notificationCount, 2)
        XCTAssertEqual(retained.notificationCount, 1)

        center.removeIssuesListener(removed)
        center.removeIssuesListener(removed)
        center.forceNotify()
        XCTAssertEqual(removed.notificationCount, 2)
        XCTAssertEqual(retained.notificationCount, 2)
    }

    func testAppChainRemovalUnsubscribesEveryRegistrationAndPreservesOtherListeners() {
        let center = ChainsIssuesCenter(
            wallet: AccountGenerator.generateMetaAccount(),
            networkIssuesCenter: NoopNetworkIssuesCenter(),
            eventCenter: EventCenter(),
            missingAccountHelper: NoMissingAccounts(),
            accountInfoFetcher: NoIssueAccountInfo()
        )
        let removed = ChainsIssuesListenerSpy()
        let retained = ChainsIssuesListenerSpy()
        center.addIssuesListener(removed, getExisting: false)
        center.addIssuesListener(removed, getExisting: false)
        center.addIssuesListener(retained, getExisting: false)
        center.handleChainsWithIssues([])
        XCTAssertEqual(removed.notificationCount, 2)
        XCTAssertEqual(retained.notificationCount, 1)

        center.removeIssuesListener(removed)
        center.removeIssuesListener(removed)
        center.handleChainsWithIssues([])
        XCTAssertEqual(removed.notificationCount, 2)
        XCTAssertEqual(retained.notificationCount, 2)
    }
}

final class IssuesCenterReachabilityTests: XCTestCase {
    func testNativeUnreachableConnectionNotifiesOnceAndClearsWhenConnected() {
        let center = NetworkIssuesCenterImpl.shared
        let chainId = UUID().uuidString
        let listener = NativeIssuesListenerSpy()
        let lateListener = NativeIssuesListenerSpy()
        defer {
            center.removeIssuesListener(listener)
            center.removeIssuesListener(lateListener)
            center.handle(chain: chainId, state: .connected)
        }
        center.addIssuesListener(listener, getExisting: false)

        center.handle(chain: chainId, state: .notReachable)
        XCTAssertTrue(listener.lastChainIds.contains(chainId))
        XCTAssertEqual(listener.notificationCount, 1)
        center.addIssuesListener(lateListener, getExisting: true)
        XCTAssertTrue(lateListener.lastChainIds.contains(chainId))

        center.handle(chain: chainId, state: .notReachable)
        center.handle(chain: chainId, state: .connecting(attempt: 0))
        XCTAssertEqual(listener.notificationCount, 1)
        XCTAssertTrue(listener.lastChainIds.contains(chainId))

        center.handle(chain: chainId, state: .connected)
        XCTAssertFalse(listener.lastChainIds.contains(chainId))
        XCTAssertFalse(lateListener.lastChainIds.contains(chainId))
        XCTAssertEqual(listener.notificationCount, 2)
        center.handle(chain: chainId, state: .connected)
        XCTAssertEqual(listener.notificationCount, 2)
    }

    func testAppUnreachableConnectionNotifiesOnceAndClearsWhenConnected() throws {
        let center = NetworkIssuesCenter.shared
        let chain = try XCTUnwrap(ChainModelGenerator.generate(count: 1).first)
        let listener = NetworkIssuesListenerSpy()
        let lateListener = NetworkIssuesListenerSpy()
        defer {
            center.removeIssuesListener(listener)
            center.removeIssuesListener(lateListener)
            center.processChainReconnecting(event: ChainReconnectingEvent(chain: chain, state: .connected))
        }
        center.addIssuesListener(listener, getExisting: false)

        center.processChainReconnecting(event: ChainReconnectingEvent(chain: chain, state: .notReachable))
        XCTAssertTrue(listener.lastChainIds.contains(chain.chainId))
        XCTAssertEqual(listener.notificationCount, 1)
        center.addIssuesListener(lateListener, getExisting: true)
        XCTAssertTrue(lateListener.lastChainIds.contains(chain.chainId))

        center.processChainReconnecting(event: ChainReconnectingEvent(chain: chain, state: .notReachable))
        center.processChainReconnecting(event: ChainReconnectingEvent(chain: chain, state: .connecting(attempt: 0)))
        XCTAssertEqual(listener.notificationCount, 1)
        XCTAssertTrue(listener.lastChainIds.contains(chain.chainId))

        center.processChainReconnecting(event: ChainReconnectingEvent(chain: chain, state: .connected))
        XCTAssertFalse(listener.lastChainIds.contains(chain.chainId))
        XCTAssertFalse(lateListener.lastChainIds.contains(chain.chainId))
        XCTAssertEqual(listener.notificationCount, 2)
        center.processChainReconnecting(event: ChainReconnectingEvent(chain: chain, state: .connected))
        XCTAssertEqual(listener.notificationCount, 2)
    }
}

private final class NativeIssuesListenerSpy: ConnectionIssuesCenterListener {
    private(set) var notificationCount = 0
    private(set) var lastChainIds: Set<ChainModel.Id> = []

    func handleChainsWithIssues(_ chains: [ChainModel.Id]) {
        notificationCount += 1
        lastChainIds = Set(chains)
    }
}

private final class NetworkIssuesListenerSpy: NetworkIssuesCenterListener {
    private(set) var notificationCount = 0
    private(set) var lastChainIds: Set<ChainModel.Id> = []

    func handleChainsWithIssues(_ chains: [ChainModel]) {
        notificationCount += 1
        lastChainIds = Set(chains.map(\.chainId))
    }
}

private final class ChainsIssuesListenerSpy: ChainsIssuesCenterListener {
    private(set) var notificationCount = 0

    func handleChainsIssues(_: [ChainIssue]) {
        notificationCount += 1
    }
}

private struct NoMissingAccounts: MissingAccountFetcherProtocol {
    func fetchMissingAccounts(for _: MetaAccountModel, complection: @escaping ([ChainModel]) -> Void) {
        complection([])
    }
}

private struct NoIssueAccountInfo: AccountInfoFetchingProtocol {
    func fetch(
        for chainAsset: ChainAsset,
        accountId _: AccountId,
        completionBlock: @escaping (ChainAsset, AccountInfo?) -> Void
    ) {
        completionBlock(chainAsset, nil)
    }

    func fetch(
        for _: [ChainAsset],
        wallet _: MetaAccountModel,
        completionBlock: @escaping ([ChainAsset: AccountInfo?]) -> Void
    ) {
        completionBlock([:])
    }

    func fetch(for chainAsset: ChainAsset, accountId _: AccountId) async throws -> (ChainAsset, AccountInfo?) {
        (chainAsset, nil)
    }

    func fetch(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAsset: AccountInfo?] {
        [:]
    }

    func fetchByUniqKey(for _: [ChainAsset], wallet _: MetaAccountModel) async throws -> [ChainAssetKey: AccountInfo?] {
        [:]
    }
}

final class RemoteSubscriptionCompletionTests: XCTestCase {
    func testFailureCompletesAllWaitersOnceAndAllowsRetry() throws {
        let operations = ControlledSubscriptionOperations()
        let service = makeService(operations: operations)
        let completed = expectation(description: "both initial waiters fail")
        completed.assertForOverFulfill = true
        completed.expectedFulfillmentCount = 2
        var callbackCount = 0
        for _ in 0 ..< 2 {
            service.attachToSubscription(with: [], chainId: "test", cacheKey: "key", queue: .main) { result in
                if case let .failure(error) = result {
                    XCTAssertNotNil(error as? ChainRegistryError)
                } else {
                    XCTFail("Missing runtime must fail initialization")
                }
                callbackCount += 1
                completed.fulfill()
            }
        }
        XCTAssertEqual(operations.targets.count, 1)
        let first = try XCTUnwrap(operations.targets.first)
        first.completionBlock?()
        first.completionBlock?()
        wait(for: [completed], timeout: 1)
        XCTAssertEqual(callbackCount, 2)

        let retried = expectation(description: "retry has its own completion")
        retried.assertForOverFulfill = true
        service.attachToSubscription(with: [], chainId: "test", cacheKey: "key", queue: .main) { result in
            if case .success = result {
                XCTFail("Missing runtime must still fail")
            }
            callbackCount += 1
            retried.fulfill()
        }
        guard operations.targets.count == 2 else {
            XCTFail("Failed initialization must release the pending entry for retry")
            return
        }
        operations.targets[1].completionBlock?()
        wait(for: [retried], timeout: 1)
        XCTAssertEqual(callbackCount, 3)
    }

    func testDetachedOldSuccessCannotCompleteReplacementRequest() throws {
        let operations = ControlledSubscriptionOperations()
        let service = makeService(operations: operations)
        let detachedCallback = expectation(description: "detached waiter is not called")
        detachedCallback.isInverted = true
        let originalId = service.attachToSubscription(
            with: [], chainId: "test", cacheKey: "key", queue: .main
        ) { _ in detachedCallback.fulfill() }
        let old = try XCTUnwrap(operations.targets.first)
        service.detachFromSubscription("key", subscriptionId: originalId, queue: .main, closure: nil)
        XCTAssertTrue(old.isCancelled)

        let prematureCallback = expectation(description: "old completion does not complete new waiter")
        prematureCallback.isInverted = true
        let currentCallback = expectation(description: "replacement reports its own result")
        currentCallback.assertForOverFulfill = true
        var completingCurrent = false
        service.attachToSubscription(with: [], chainId: "test", cacheKey: "key", queue: .main) { result in
            guard completingCurrent else {
                prematureCallback.fulfill()
                return
            }
            if case .success = result {
                XCTFail("The replacement has no runtime")
            }
            currentCallback.fulfill()
        }
        XCTAssertEqual(operations.targets.count, 2)
        old.result = .success(StorageSubscriptionContainer(
            engine: MockConnection(),
            children: [],
            logger: Logger.shared
        ))
        old.completionBlock?()
        wait(for: [detachedCallback, prematureCallback], timeout: 0.2)

        completingCurrent = true
        operations.targets[1].completionBlock?()
        wait(for: [currentCallback], timeout: 1)
    }

    func testCancelledCurrentInitializationCompletesOnceAndAllowsRetry() throws {
        let operations = ControlledSubscriptionOperations()
        let service = makeService(operations: operations)
        let completed = expectation(description: "cancelled initialization finishes")
        completed.assertForOverFulfill = true
        service.attachToSubscription(with: [], chainId: "test", cacheKey: "key", queue: .main) { result in
            if case let .failure(error) = result {
                guard case .parentOperationCancelled = error as? BaseOperationError else {
                    return XCTFail("Expected operation cancellation, received \(error)")
                }
            } else {
                XCTFail("Cancellation cannot succeed")
            }
            completed.fulfill()
        }
        let first = try XCTUnwrap(operations.targets.first)
        first.cancel()
        first.result = nil
        first.completionBlock?()
        first.completionBlock?()
        wait(for: [completed], timeout: 1)
        service.attachToSubscription(with: [], chainId: "test", cacheKey: "key", queue: .main, closure: nil)
        XCTAssertEqual(operations.targets.count, 2)
    }

    func testSuccessfulInitializationCompletesOnceAndReusesActiveSubscription() throws {
        let operations = ControlledSubscriptionOperations()
        let service = makeService(operations: operations)
        let completed = expectation(description: "initial subscription succeeds")
        completed.assertForOverFulfill = true
        var callbackCount = 0
        let firstId = service.attachToSubscription(
            with: [], chainId: "test", cacheKey: "key", queue: .main
        ) { result in
            if case .failure = result {
                XCTFail("Expected the controlled successful result")
            }
            callbackCount += 1
            completed.fulfill()
        }
        let first = try XCTUnwrap(operations.targets.first)
        first.result = .success(StorageSubscriptionContainer(
            engine: MockConnection(),
            children: [],
            logger: Logger.shared
        ))
        first.completionBlock?()
        first.completionBlock?()
        wait(for: [completed], timeout: 1)
        XCTAssertEqual(callbackCount, 1)
        let reused = expectation(description: "active subscription is reused")
        reused.assertForOverFulfill = true
        let secondId = service.attachToSubscription(
            with: [], chainId: "test", cacheKey: "key", queue: .main
        ) { result in
            if case .failure = result {
                XCTFail("Active subscription should succeed")
            }
            reused.fulfill()
        }
        wait(for: [reused], timeout: 1)
        XCTAssertEqual(operations.targets.count, 1)
        service.detachFromSubscription("key", subscriptionId: firstId, queue: .main, closure: nil)
        service.detachFromSubscription("key", subscriptionId: secondId, queue: .main, closure: nil)
    }

    private func makeService(
        operations: ControlledSubscriptionOperations
    ) -> RemoteSubscriptionService<ChainStorageItem> {
        let registry = MockChainRegistryProtocol()
        stub(registry) { $0.getRuntimeProvider(for: any()).thenReturn(nil) }
        return RemoteSubscriptionService(
            chainRegistry: registry,
            repository: AnyDataProviderRepository(SubscriptionTestRepository()),
            operationManager: operations,
            logger: Logger.shared
        )
    }
}

private final class ControlledSubscriptionOperations: OperationManagerProtocol {
    private(set) var targets: [BaseOperation<StorageSubscriptionContainer>] = []

    func enqueue(operations: [Operation], in _: OperationMode) {
        // Missing-runtime wrappers contain one pre-failed operation. Keep its real completion
        // handler under test control to exercise late and repeated delivery without networking.
        XCTAssertEqual(operations.count, 1)
        if let target = operations.last as? BaseOperation<StorageSubscriptionContainer> {
            targets.append(target)
        } else {
            XCTFail("Expected the subscription initialization target")
        }
    }
}

private final class SubscriptionTestRepository:
    DataProviderRepositoryProtocol {
    typealias Model = ChainStorageItem

    func fetchOperation(
        by _: @escaping () throws -> [String],
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainStorageItem]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: @escaping () throws -> String,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<ChainStorageItem?> {
        ClosureOperation { nil }
    }

    func fetchAllOperation(
        with _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainStorageItem]> {
        ClosureOperation { [] }
    }

    func fetchOperation(
        by _: RepositorySliceRequest,
        options _: RepositoryFetchOptions
    ) -> BaseOperation<[ChainStorageItem]> {
        ClosureOperation { [] }
    }

    func saveOperation(
        _: @escaping () throws -> [ChainStorageItem],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func saveBatchOperation(
        _: @escaping () throws -> [ChainStorageItem],
        _: @escaping () throws -> [String]
    ) -> BaseOperation<Void> {
        ClosureOperation { () }
    }

    func replaceOperation(
        _: @escaping () throws -> [ChainStorageItem]
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

extension ChainRegistryTests {
    func testChosenEthereumNodeTakesEffectInSessionAndAutomaticSelectionResumesOnTheNodeMovedTo() throws {
        let (provider, observable) = makeChainProvider()
        let first = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "https://first-rpc.example")),
            name: "First Ethereum RPC",
            apikey: nil
        )
        let second = ChainNodeModel(
            url: try XCTUnwrap(URL(string: "https://second-rpc.example")),
            name: "Second Ethereum RPC",
            apikey: nil
        )
        let chainId = "ethereum-node-choice-chain"
        let automatic = makeEthereumChain(identifier: chainId, node: first)
            .replacingNodes([first, second])
            .replacingSelectedNode(nil)
        let suite = "ChainRegistryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let pool = EthereumConnectionPool(
            nodeFetching: EthereumNodeFetching(),
            catalogOrder: EthereumNodeCatalogOrder(defaults: defaults)
        )
        let registry = ChainRegistry(
            snapshotHotBootBuilder: NoopSnapshotHotBootBuilder(),
            runtimeProviderPool: makeRuntimeProviderPool(),
            connectionPools: [pool],
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

        XCTAssertTrue(observable.send([.insert(newItem: automatic)]))
        let firstConnection: Web3.Eth = try waitForValue {
            registry.getEthereumConnection(for: chainId)
        }
        XCTAssertEqual(pool.currentNodeURL(for: chainId), first.url)

        // The first node stops answering, and the network moves on.
        XCTAssertNotNil(registry.failoverEthereumConnection(for: chainId, failed: firstConnection))
        XCTAssertEqual(pool.currentNodeURL(for: chainId), second.url)

        // The user chooses the first node as the node selection screen does: a reset, then the saved chain.
        registry.resetConnection(for: chainId)
        XCTAssertNil(pool.getConnection(for: chainId))
        XCTAssertTrue(observable.send([.update(newItem: automatic.replacingSelectedNode(first))]))
        try waitForCondition {
            pool.currentNodeURL(for: chainId) == first.url
        }
        let chosenConnection = try XCTUnwrap(registry.getEthereumConnection(for: chainId))

        // A node the user chose is kept when it fails: rebuilt, never swapped.
        let rebuilt = try XCTUnwrap(registry.failoverEthereumConnection(for: chainId, failed: chosenConnection))
        XCTAssertEqual(pool.currentNodeURL(for: chainId), first.url)
        XCTAssertFalse(
            (rebuilt.properties.provider as? EthereumNodeProvider) ===
                (chosenConnection.properties.provider as? EthereumNodeProvider)
        )

        // Back to automatic selection: the network resumes on the node it moved to, not on the one that failed.
        registry.resetConnection(for: chainId)
        XCTAssertTrue(observable.send([.update(newItem: automatic)]))
        try waitForCondition {
            registry.getChain(for: chainId)?.selectedNode == nil &&
                pool.currentNodeURL(for: chainId) == second.url
        }

        provider.removeObserver(registry)
    }
}
