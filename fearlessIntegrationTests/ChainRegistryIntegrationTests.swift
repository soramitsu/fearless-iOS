import XCTest
import FearlessFoundation
import RobinHood
import SSFModels
import SSFUtils
@testable import fearless

final class ChainRegistryIntegrationTests: XCTestCase {
    func testColdBoot_whenChainsAvailable_thenRegistersRuntimeProvidersAndConnections() throws {
        let chains = ChainModelGenerator.generate(count: 3)
        let expectedChainIds = Set(chains.map(\.chainId))
        let storageFacade = SubstrateStorageTestFacade()
        try seed(chains: chains, in: storageFacade)

        let dataOperationFactory = StaticDataOperationFactory(
            data: try JSONEncoder().encode(chains)
        )
        let connectionFactory = RegistryConnectionFactorySpy()
        let registry = ChainRegistryFactory.createDefaultRegistry(
            from: storageFacade,
            dependencies: makeDependencies(
                dataOperationFactory: dataOperationFactory,
                connectionFactory: connectionFactory
            )
        )

        registry.performColdBoot()

        XCTAssertTrue(waitUntil(timeout: 10) {
            Set(registry.availableChains.map(\.chainId)) == expectedChainIds
        }, "Available chains: \(registry.availableChains.map(\.chainId)); requested URLs: \(dataOperationFactory.requestedURLs)")

        XCTAssertTrue(waitUntil(timeout: 10) {
            chains.allSatisfy { registry.getConnection(for: $0.chainId) != nil }
        }, "Created connections: \(connectionFactory.createdConnectionNames)")

        XCTAssertTrue(waitUntil(timeout: 10) {
            dataOperationFactory.requestedURLs.isNotEmpty
        })

        XCTAssertEqual(Set(registry.availableChains.map(\.chainId)), expectedChainIds)
        XCTAssertEqual(registry.availableChainIds, expectedChainIds)
        XCTAssertEqual(Set(connectionFactory.createdConnectionNames.compactMap { $0 }), expectedChainIds)
        XCTAssertGreaterThanOrEqual(dataOperationFactory.requestedURLs.count, 1)

        chains.forEach { chain in
            XCTAssertNotNil(registry.getConnection(for: chain.chainId))
            XCTAssertNotNil(registry.getRuntimeProvider(for: chain.chainId))
        }
    }

    func testResetConnection_whenChainIsAvailable_thenRemovesCachedConnection() throws {
        let chains = ChainModelGenerator.generate(count: 3)
        let chain = try XCTUnwrap(chains.first)
        let storageFacade = SubstrateStorageTestFacade()
        try seed(chains: chains, in: storageFacade)

        let dataOperationFactory = StaticDataOperationFactory(
            data: try JSONEncoder().encode(chains)
        )
        let connectionFactory = RegistryConnectionFactorySpy()
        let registry = ChainRegistryFactory.createDefaultRegistry(
            from: storageFacade,
            dependencies: makeDependencies(
                dataOperationFactory: dataOperationFactory,
                connectionFactory: connectionFactory
            )
        )

        registry.subscribeToChains()

        XCTAssertTrue(waitUntil(timeout: 10) {
            registry.availableChains.contains { $0.chainId == chain.chainId }
        }, "Available chains: \(registry.availableChains.map(\.chainId)); requested URLs: \(dataOperationFactory.requestedURLs)")
        XCTAssertTrue(waitUntil { registry.getConnection(for: chain.chainId) != nil }, "Created connections: \(connectionFactory.createdConnectionNames)")

        registry.resetConnection(for: chain.chainId)

        XCTAssertNil(registry.getConnection(for: chain.chainId))
    }

    private func waitUntil(
        timeout: TimeInterval = 5,
        condition: @escaping () -> Bool
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            if condition() {
                return true
            }

            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }

        return condition()
    }

    private func seed(
        chains: [ChainModel],
        in storageFacade: fearless.StorageFacadeProtocol
    ) throws {
        let repository = ChainRepositoryFactory(storageFacade: storageFacade).createRepository()
        let saveOperation = repository.saveOperation({ chains }, { [] })
        let queue = OperationQueue()

        queue.addOperations([saveOperation], waitUntilFinished: true)

        _ = try saveOperation.extractResultData(
            throwing: BaseOperationError.parentOperationCancelled
        )
    }

    private func makeDependencies(
        dataOperationFactory: DataOperationFactoryProtocol,
        connectionFactory: ConnectionFactoryProtocol
    ) -> ChainRegistryFactoryDependencies {
        var dependencies = ChainRegistryFactoryDependencies.live
        dependencies.eventCenter = EventCenter()
        dependencies.dataOperationFactory = dataOperationFactory
        dependencies.runtimeQueue = OperationQueue()
        dependencies.syncQueue = OperationQueue()
        dependencies.operationManager = OperationManager()
        dependencies.connectionFactory = connectionFactory
        dependencies.ethereumConnectionPool = EthereumConnectionPool()
        dependencies.applicationHandler = ApplicationHandler()
        return dependencies
    }
}

private final class StaticDataOperationFactory: DataOperationFactoryProtocol {
    private let data: Data
    private let lock = NSLock()
    private var urls: [URL] = []
    var requestedURLs: [URL] {
        lock.lock()
        defer { lock.unlock() }

        return urls
    }

    init(data: Data) {
        self.data = data
    }

    func fetchData(from url: URL) -> BaseOperation<Data> {
        lock.lock()
        urls.append(url)
        lock.unlock()

        return ClosureOperation { [data] in data }
    }
}

private final class RegistryConnectionFactorySpy: ConnectionFactoryProtocol {
    private let lock = NSLock()
    private var connectionNames: [String?] = []
    private var urls: [[URL]] = []
    private var retainedConnections: [ChainConnection] = []
    var createdConnectionNames: [String?] {
        lock.lock()
        defer { lock.unlock() }

        return connectionNames
    }

    var createdURLs: [[URL]] {
        lock.lock()
        defer { lock.unlock() }

        return urls
    }

    func createConnection(
        connectionName: String?,
        for urls: [URL],
        delegate _: WebSocketEngineDelegate
    ) throws -> ChainConnection {
        let connection = RegistryConnectionSpy()
        connection.connectionName = connectionName
        connection.url = urls.first

        lock.lock()
        connectionNames.append(connectionName)
        self.urls.append(urls)
        retainedConnections.append(connection)
        lock.unlock()

        return connection
    }
}

private final class RegistryConnectionSpy: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private var nextId: UInt16 = 1
    private var subscriptions: [UInt16: (Any) -> Void] = [:]

    func callMethod<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let id = generateRequestId()
        closure?(.failure(JSONRPCEngineError.clientCancelled))
        return id
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        let id = generateRequestId()
        subscriptions[id] = { value in
            guard let typedValue = value as? T else {
                return
            }

            updateClosure(typedValue)
        }
        return id
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        subscriptions.removeValue(forKey: identifier)
    }

    func generateRequestId() -> UInt16 {
        defer { nextId &+= 1 }
        return nextId
    }

    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws { cancelForIdentifier(identifier) }
}
