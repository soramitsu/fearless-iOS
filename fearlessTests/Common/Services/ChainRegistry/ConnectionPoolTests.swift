import XCTest
@testable import fearless
import Cuckoo
@testable import SSFUtils
import SSFModels
import Starscream

class ConnectionPoolTests: XCTestCase {
    func testSetupCreatesNewConnections() {
        do {
            // given

            let connectionFactory = MockConnectionFactoryProtocol()

            stub(connectionFactory) { stub in
                stub.createConnection(connectionName: any(), for: any(), delegate: any()).then { _ in
                    MockConnection()
                }
            }

            let connectionPool = ConnectionPool(connectionFactory: connectionFactory)

            // when

            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)

            let connections: [JSONRPCEngine] = try chainModels.reduce([]) { allConnections, chain in
                let connection = try connectionPool.setupConnection(for: chain)
                return allConnections + [connection]
            }

            // then

            let actualChainIds = Set(connectionPool.connections.map { $0.chainId })
            let expectedChainIds = Set(chainModels.map { $0.chainId })

            XCTAssertEqual(expectedChainIds, actualChainIds)
            XCTAssertEqual(connections.count, expectedChainIds.count)
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }

    func testEthereumConnectionPoolResetRemovesConnectionForChainId() throws {
        let chainId = "e2e-eth-test-chain"
        let chain = makeEthereumLikeChain(chainId: chainId)
        let pool = EthereumConnectionPool()

        _ = try pool.setupConnection(for: chain)

        XCTAssertNotNil(pool.getConnection(for: chainId))

        pool.resetConnection(for: chainId)

        XCTAssertNil(pool.getConnection(for: chainId))
    }

    func testAtomicConnectionLookupKeepsSnapshotDuringConcurrentReset() {
        let pool = ConnectionPool(connectionFactory: RecordingSubstrateFactory())
        let first = MockConnection()
        let second = MockConnection()
        pool.connections.append(.init(chainId: "first", connection: WeakWrapper(target: first)))
        pool.connections.append(.init(chainId: "second", connection: WeakWrapper(target: second)))
        let resetFinished = DispatchSemaphore(value: 0)

        let found = pool.connections.first { wrapper in
            if wrapper.chainId == "first" {
                DispatchQueue.global().async {
                    pool.resetConnection(for: "first")
                    // Wait for the queued removal before continuing the lookup.
                    XCTAssertEqual(pool.connections.endIndex, 1)
                    resetFinished.signal()
                }
                XCTAssertEqual(resetFinished.wait(timeout: .now() + 3), .success)
            }
            return wrapper.chainId == "second"
        }

        XCTAssertTrue(found?.connection.target === second)
        XCTAssertEqual(first.disconnectCallCount, 1)
        XCTAssertNil(pool.getConnection(for: "first"))
        XCTAssertTrue(pool.getConnection(for: "second") === second)
    }

    func testConcurrentConnectionResetsAndLookupsKeepMatchingIdentity() {
        let pool = ConnectionPool(connectionFactory: RecordingSubstrateFactory())
        let first = MockConnection()
        let second = MockConnection()
        let entries = [
            ConnectionPool.ConnectionWrapper(chainId: "first", connection: WeakWrapper(target: first)),
            ConnectionPool.ConnectionWrapper(chainId: "second", connection: WeakWrapper(target: second))
        ]
        pool.connections.replace(array: entries)
        let work = DispatchGroup()
        let queue = DispatchQueue(label: "test.connection.lookup.reset", attributes: .concurrent)
        queue.async(group: work) {
            for _ in 0 ..< 1000 {
                pool.connections.replace(array: entries)
                pool.resetConnection(for: "first")
                pool.resetConnection(for: "second")
            }
        }
        for _ in 0 ..< 4 {
            queue.async(group: work) {
                for _ in 0 ..< 1000 {
                    if let connection = pool.getConnection(for: "first") {
                        XCTAssertTrue(connection === first)
                    }
                    if let connection = pool.getConnection(for: "second") {
                        XCTAssertTrue(connection === second)
                    }
                }
            }
        }
        XCTAssertEqual(work.wait(timeout: .now() + 10), .success)
        pool.connections.replace(array: [])
        XCTAssertNil(pool.getConnection(for: "first"))
        XCTAssertNil(pool.getConnection(for: "second"))
        XCTAssertGreaterThan(first.disconnectCallCount, 0)
        XCTAssertGreaterThan(second.disconnectCallCount, 0)
    }

    private func makeEthereumLikeChain(chainId: String) -> ChainModel {
        let node = ChainNodeModel(
            url: URL(string: "https://rpc.unit.test")!,
            name: "Unit Test ETH Node",
            apikey: nil
        )

        return ChainModel(
            rank: nil,
            disabled: false,
            chainId: chainId,
            parentId: nil,
            paraId: nil,
            name: "Unit ETH",
            xcm: nil,
            nodes: Set([node]),
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }

//    func testSetupUpdatesExistingConnection() {
//        do {
//            // given
//
//            let connectionFactory = MockConnectionFactoryProtocol()
//
//            let setupConnection: () -> MockConnection = {
//                let mockConnection = MockConnection()
//                stub(mockConnection.autobalancing) { stub in
//                    stub.set(ranking: any()).thenDoNothing()
//                    stub.url.get.then { URL(string: "https://github.com") }
//                }
//
//                return mockConnection
//            }
//
//            stub(connectionFactory) { stub in
//                stub.createConnection(connectionName: any(), for: any(), delegate: any()).then { _ in
//                    setupConnection()
//                }
//            }
//
//            let connectionPool = ConnectionPool(connectionFactory: connectionFactory)
//
//            // when
//
//            let chainModels: [ChainModel] = ChainModelGenerator.generate(count: 10)
//
//            let newConnections: [MockConnection] = try chainModels.reduce(
//                []
//            ) { (allConnections, chain) in
//                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
//                    return allConnections + [connection]
//                } else {
//                    return allConnections
//                }
//            }
//
//            let updatedConnections: [MockConnection] = try chainModels.reduce(
//                []
//            ) { (allConnections, chain) in
//                if let connection = try connectionPool.setupConnection(for: chain) as? MockConnection {
//                    return allConnections + [connection]
//                } else {
//                    return allConnections
//                }
//            }
//
//            // then
//
//            let actualChainIds = Set(connectionPool.connectionsByChainIds.keys)
//            let expectedChainIds = Set(chainModels.map { $0.chainId })
//
//            XCTAssertEqual(expectedChainIds, actualChainIds)
//            XCTAssertEqual(newConnections.count, updatedConnections.count)
//
//            for index in 0..<newConnections.count {
//                XCTAssertTrue(newConnections[index] === updatedConnections[index])
//                verify(newConnections[index].autobalancing, times(1)).set(ranking: any())
//            }
//        } catch {
//            XCTFail("Did receive error \(error)")
//        }
//    }
}

final class SubstrateNodeSelectionTests: XCTestCase {
    func testSelectedUnavailableNodeKeepsCatalogFallbacksAndStoredIdentity() throws {
        let selected = node("wss://api-polkadot.dwellir.com", name: "My saved node")
        let publicNode = node("wss://polkadot.publicnode.com/custom/path?network=dot")
        let chain = makeChain(nodes: [publicNode, selected], selected: selected)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let original = try encoder.encode(chain)
        let factory = RecordingSubstrateFactory()
        let pool = ConnectionPool(connectionFactory: factory, injector: NodeApiKeyInjector(apiKey: ""))
        let connection = try pool.setupConnection(for: chain)
        XCTAssertEqual(factory.urls, [selected.url, publicNode.url])
        XCTAssertEqual(try encoder.encode(chain), original)
        XCTAssertTrue(pool.getConnection(for: chain.chainId) === connection)
    }

    func testSelectedCustomCredentialsPathAndQueryArePreservedExactly() throws {
        let custom = node("wss://user:own-password@custom.example:9443/rpc/path?access=own-value", name: "Dwellir Custom")
        let catalog = node("wss://catalog.example/rpc")
        let factory = RecordingSubstrateFactory()
        let pool = ConnectionPool(connectionFactory: factory, injector: NodeApiKeyInjector(apiKey: "synthetic-provider-key"))
        _ = try pool.setupConnection(for: makeChain(nodes: [catalog], selected: custom))
        XCTAssertEqual(factory.urls, [custom.url, catalog.url])
    }

    func testLegacySelectedPlainWebSocketRemainsFirst() throws {
        let custom = node("ws://localhost:9944/rpc")
        let publicNode = node("wss://public.example")
        let factory = RecordingSubstrateFactory()
        _ = try ConnectionPool(connectionFactory: factory).setupConnection(for: makeChain(nodes: [publicNode], selected: custom))
        XCTAssertEqual(factory.urls, [custom.url, publicNode.url])
    }

    func testCatalogOrderIsStableAndDuplicateURLsAreTriedOnce() throws {
        let first = node("wss://a.example")
        let second = node("wss://b.example")
        let duplicate = node("wss://a.example", name: "Different display name")
        for _ in 0 ..< 10 {
            let factory = RecordingSubstrateFactory()
            _ = try ConnectionPool(connectionFactory: factory).setupConnection(for: makeChain(nodes: [second, duplicate, first], selected: nil))
            XCTAssertEqual(factory.urls, [first.url, second.url])
        }
    }

    func testUnsupportedSelectedProtocolFallsBackWithoutRewritingSelection() throws {
        let unsupported = node("https://old-http.example/rpc")
        let supported = node("wss://public.example")
        let chain = makeChain(nodes: [supported], selected: unsupported)
        let factory = RecordingSubstrateFactory()
        _ = try ConnectionPool(connectionFactory: factory).setupConnection(for: chain)
        XCTAssertEqual(factory.urls, [supported.url])
        XCTAssertEqual(chain.selectedNode, unsupported)
    }

    func testNoEligibleNodesFailsBeforeCreatingEngineWithActionableError() {
        for nodes in [Set<ChainNodeModel>(), [node("https://http-only.example")]] {
            let factory = RecordingSubstrateFactory()
            XCTAssertThrowsError(try ConnectionPool(connectionFactory: factory).setupConnection(for: makeChain(nodes: nodes, selected: nil))) { error in
                guard case ConnectionPoolError.noConnection = error else { return XCTFail("Unexpected error") }
                XCTAssertTrue(error.localizedDescription.contains("network settings"))
            }
            XCTAssertNil(factory.urls)
        }
    }

    private func node(_ address: String, name: String = "Synthetic node") -> ChainNodeModel {
        ChainNodeModel(url: URL(string: address)!, name: name, apikey: nil)
    }

    private func makeChain(nodes: Set<ChainNodeModel>, selected: ChainNodeModel?) -> ChainModel {
        ChainModel(
            rank: nil,
            disabled: false,
            chainId: "synthetic-legacy-chain",
            parentId: nil,
            paraId: nil,
            name: "Synthetic legacy network",
            xcm: nil,
            nodes: nodes,
            addressPrefix: 0,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: nil,
            selectedNode: selected,
            customNodes: selected.map { [$0] },
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

final class NodeApiKeyInjectorTests: XCTestCase {
    func testAuthenticatedDwellirHostsReceiveKeyRegardlessOfDisplayName() {
        let urls = ["wss://api-polkadot.dwellir.com", "wss://api-kusama.n.dwellir.com/", "wss://API-POLKADOT.n.DWELLIR.COM:443"]
        for address in urls {
            let original = URL(string: address)!
            XCTAssertEqual(inject(address, name: "Renamed saved node"), original.appendingPathComponent("synthetic-provider-key"))
        }
    }

    func testDisplayNameCannotAttachCredentialToCustomOrLookalikeHost() {
        let urls = ["wss://custom.example", "wss://api-polkadot.dwellir.com.attacker.example",
                    "wss://dwellir.com", "wss://api-polkadot.evil.dwellir.com", "wss://evil-api-polkadot.dwellir.com",
                    "wss://api-.dwellir.com", "wss://api-polkadot.dwellir.com:9443"]
        for address in urls {
            XCTAssertEqual(inject(address, name: "DWELLIR"), URL(string: address), address)
        }
    }

    func testPublicDwellirRPCHostsNeverReceiveCredential() {
        for address in ["wss://polkadot-rpc.dwellir.com", "wss://hydration-rpc.n.dwellir.com"] {
            XCTAssertEqual(inject(address), URL(string: address))
        }
    }

    func testPreexistingCredentialPathQueryOrUserInfoIsNeverChanged() {
        for suffix in ["/existing-key", "/rpc/path", "/%2F", "?key=owned", "?", "#custom"] {
            let address = "wss://api-polkadot.n.dwellir.com" + suffix
            XCTAssertEqual(inject(address), URL(string: address))
        }
        let address = "wss://user:password@api-polkadot.n.dwellir.com/"
        XCTAssertEqual(inject(address), URL(string: address))
    }

    func testInsecureOrNonWebSocketTransportNeverReceivesCredential() {
        for scheme in ["ws", "http", "https", "ftp"] {
            let address = scheme + "://api-polkadot.n.dwellir.com"
            XCTAssertEqual(inject(address), URL(string: address))
        }
    }

    func testMissingPlaceholderOrMalformedOptionalCredentialKeepsOriginalURL() {
        let address = "wss://api-polkadot.n.dwellir.com"
        for key in ["", "true", "FALSE", "null", "undefined", " key ", "key/path", "key?query", "key\nvalue"] {
            XCTAssertEqual(inject(address, key: key), URL(string: address))
        }
    }

    private func inject(_ address: String, name: String = "Dwellir", key: String = "synthetic-provider-key") -> URL? {
        NodeApiKeyInjector(apiKey: key).injectKey(nodes: [ChainNodeModel(url: URL(string: address)!, name: name, apikey: nil)]).first
    }
}

final class FailoverChainConnectionTests: XCTestCase {
    func testGuardedCancellationForwardsExactAuthorizerIdentity() throws {
        let transport = SyntheticSubstrateTransport { _, _ in false }
        transport.emitStartEvents = false
        let connection = try makeConnection(urls: [URL(string: "wss://pending.example")!], transport: transport, delegate: RecordingSubstrateDelegate())
        defer { connection.disconnectIfNeeded() }
        let authority = PendingMutationAuthority()
        let cancelled = expectation(description: "pending guarded request removed")
        let id = try connection.callMethod("author_submitExtrinsic", params: ["signed-fixture"], options: JSONRPCOptions(writeAuthorization: authority)) { (result: Result<String, Error>) in
            guard case .failure(let error) = result else { return XCTFail("Expected cancellation") }
            XCTAssertEqual(error as? JSONRPCEngineError, .requestNotSent)
            cancelled.fulfill()
        }
        XCTAssertEqual(connection.pendingEngineRequests.map(\.requestId), [id])
        connection.cancelForIdentifier(id, writeAuthorization: PendingMutationAuthority())
        XCTAssertEqual(connection.pendingEngineRequests.map(\.requestId), [id])
        connection.cancelForIdentifier(id, writeAuthorization: authority)
        wait(for: [cancelled], timeout: 3)
        XCTAssertTrue(connection.pendingEngineRequests.isEmpty)
        XCTAssertTrue(transport.methods.isEmpty)
    }

    func testPendingReadAndSubscriptionSurviveUnavailableSelectedNode() throws {
        let selected = URL(string: "wss://unavailable-selected.example")!
        let fallback = URL(string: "wss://healthy-catalog.example")!
        let transport = SyntheticSubstrateTransport { url, _ in url == fallback }
        let delegate = RecordingSubstrateDelegate()
        let connection = try makeConnection(urls: [selected, fallback], transport: transport, delegate: delegate)
        defer { connection.disconnectIfNeeded() }
        let read = expectation(description: "Pending read resumes on catalog node")
        let subscription = expectation(description: "Pending subscription resumes on catalog node")
        _ = try connection.callMethod("chain_getBlockHash", params: [0], options: JSONRPCOptions(resendOnReconnect: true)) { (result: Result<String, Error>) in
            XCTAssertEqual(try? result.get(), "synthetic-block-hash")
            read.fulfill()
        }
        _ = try connection.subscribe("chain_subscribeNewHeads", params: [String](), updateClosure: { (head: JSONRPCSubscriptionUpdate<String>) in
            XCTAssertEqual(head.params.result, "synthetic-head")
            subscription.fulfill()
        }, failureClosure: { _, _ in XCTFail("Subscription failed during fallback") })
        wait(for: [read, subscription], timeout: 3)
        XCTAssertEqual(connection.url, fallback)
        XCTAssertEqual(transport.startedURLs.last, fallback)
        XCTAssertTrue(transport.startedURLs.dropLast().allSatisfy { $0 == selected })
        XCTAssertGreaterThanOrEqual(transport.startedURLs.count, 4)
        XCTAssertEqual(Set(delegate.engineIdentifiers).count, 1, "Failover must keep the original request/subscription engine")
        XCTAssertEqual(Set(transport.methods), ["chain_getBlockHash", "chain_subscribeNewHeads"])
    }

    func testExhaustedNodesAreRetriedAndRecoverWithoutRecreatingWalletOrEngine() throws {
        let selected = URL(string: "wss://temporarily-offline-selected.example")!
        let fallback = URL(string: "wss://temporarily-offline-catalog.example")!
        let transport = SyntheticSubstrateTransport { url, attempt in url == selected && attempt >= 4 }
        let delegate = RecordingSubstrateDelegate()
        let connected = expectation(description: "Selected endpoint recovers after every candidate failed")
        delegate.onConnected = { connected.fulfill() }
        let connection = try makeConnection(urls: [selected, fallback], transport: transport, delegate: delegate)
        defer { connection.disconnectIfNeeded() }
        wait(for: [connected], timeout: 3)
        // Each fresh endpoint receives its bounded retry budget; exhausting the
        // catalog still returns to the selected endpoint without a wallet reset.
        XCTAssertEqual(transport.startedURLs, [selected, selected, selected, fallback, fallback, fallback, selected])
        XCTAssertEqual(connection.url, selected)
        XCTAssertEqual(Set(delegate.engineIdentifiers).count, 1)
    }

    func testSuccessfulConnectionClearsPriorFailuresForLaterOutage() throws {
        let selected = URL(string: "wss://selected.example")!
        let fallback = URL(string: "wss://catalog.example")!
        let transport = SyntheticSubstrateTransport { url, _ in url == fallback }
        let delegate = RecordingSubstrateDelegate()
        let firstConnection = expectation(description: "Catalog initially recovers")
        delegate.onConnected = { firstConnection.fulfill() }
        let connection = try makeConnection(urls: [selected, fallback], transport: transport, delegate: delegate)
        defer { connection.disconnectIfNeeded() }
        wait(for: [firstConnection], timeout: 3)
        let recovered = expectation(description: "Previously failed selection can recover a later catalog outage")
        delegate.onConnected = { recovered.fulfill() }
        transport.shouldConnect = { url, _ in url == selected }
        transport.emit(.disconnected("Synthetic catalog outage", 1006))
        wait(for: [recovered], timeout: 3)
        XCTAssertEqual(connection.url, selected)
        XCTAssertEqual(transport.startedURLs.last, selected)
        XCTAssertEqual(Set(delegate.engineIdentifiers).count, 1)
    }

    func testOneNodeKeepsRetryingUntilItRecovers() throws {
        let url = URL(string: "wss://single-custom.example")!
        let transport = SyntheticSubstrateTransport { _, attempt in attempt >= 5 }
        let delegate = RecordingSubstrateDelegate()
        let connected = expectation(description: "Single node recovery")
        delegate.onConnected = { connected.fulfill() }
        let connection = try makeConnection(urls: [url], transport: transport, delegate: delegate)
        defer { connection.disconnectIfNeeded() }
        wait(for: [connected], timeout: 3)
        XCTAssertEqual(transport.startedURLs, Array(repeating: url, count: 5))
    }

    func testEmptyCandidatesRejectBeforeTransportCreation() {
        let transport = SyntheticSubstrateTransport { _, _ in true }
        XCTAssertThrowsError(try makeConnection(urls: [], transport: transport, delegate: RecordingSubstrateDelegate())) { error in
            guard case ConnectionPoolError.noConnection = error else { return XCTFail("Unexpected error") }
        }
        XCTAssertTrue(transport.startedURLs.isEmpty)
    }

    func testProductionRetryBackoffRemainsBoundedAcrossRepeatedFailoverCycles() throws {
        let strategy = ChainReconnectionStrategy()
        XCTAssertEqual(try XCTUnwrap(strategy.reconnectAfter(attempt: 0)), 0.3, accuracy: 0.0001)
        XCTAssertGreaterThan(try XCTUnwrap(strategy.reconnectAfter(attempt: 2)), 0.3)
        for attempt in [10, 100, 1000, Int.max] {
            XCTAssertEqual(strategy.reconnectAfter(attempt: attempt), 30)
        }
    }

    private func makeConnection(urls: [URL], transport: SyntheticSubstrateTransport, delegate: RecordingSubstrateDelegate) throws -> FailoverChainConnection {
        let queue = DispatchQueue(label: "synthetic-substrate-transport")
        return try FailoverChainConnection(
            connectionName: "synthetic-legacy-wallet",
            urls: urls,
            delegate: delegate,
            processingQueue: queue,
            logger: SilentSubstrateLogger(),
            reconnectionStrategy: SyntheticSubstrateRetry(),
            engineFactory: { name, url in
                let engine = WebSocketEngine(
                    connectionName: name,
                    url: url,
                    reachabilityManager: SyntheticReachability(),
                    reconnectionStrategy: SyntheticSubstrateRetry(),
                    processingQueue: queue,
                    autoconnect: false,
                    pingInterval: 0,
                    logger: SilentSubstrateLogger()
                )
                let socket = WebSocket(request: URLRequest(url: url), engine: transport)
                engine.replacementConnectionFactory = { WebSocket(request: $0, engine: transport) }
                socket.callbackQueue = queue
                socket.delegate = engine
                engine.connection = socket
                return engine
            }
        )
    }
}

private final class RecordingSubstrateFactory: ConnectionFactoryProtocol {
    var urls: [URL]?
    func createConnection(connectionName _: String?, for urls: [URL], delegate _: WebSocketEngineDelegate) throws -> ChainConnection {
        self.urls = urls
        return MockConnection()
    }
}

private final class RecordingSubstrateDelegate: WebSocketEngineDelegate {
    var engineIdentifiers: [ObjectIdentifier] = []
    var onConnected: (() -> Void)?
    func webSocketDidChangeState(engine: WebSocketEngine, from _: WebSocketEngine.State, to newState: WebSocketEngine.State) {
        engineIdentifiers.append(ObjectIdentifier(engine))
        if case .connected = newState { onConnected?() }
    }
}

private struct SyntheticSubstrateRetry: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt _: Int) -> TimeInterval? { 0.01 }
}

private final class SyntheticReachability: ReachabilityManagerProtocol {
    let isReachable = true
    func add(listener _: ReachabilityListenerDelegate) throws {}
    func remove(listener _: ReachabilityListenerDelegate) {}
}

private struct SilentSubstrateLogger: SDKLoggerProtocol {
    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message _: String, file _: String, function _: String, line _: Int) {}
    func error(message _: String, file _: String, function _: String, line _: Int) {}
}

private final class SyntheticSubstrateTransport: Engine {
    private weak var delegate: EngineDelegate?
    var shouldConnect: (URL, Int) -> Bool
    var emitStartEvents = true
    private(set) var startedURLs: [URL] = []
    private(set) var methods: [String] = []

    init(shouldConnect: @escaping (URL, Int) -> Bool) { self.shouldConnect = shouldConnect }
    func register(delegate: EngineDelegate) { self.delegate = delegate }
    func start(request: URLRequest) {
        guard let url = request.url else { return }
        startedURLs.append(url)
        guard emitStartEvents else { return }
        let count = startedURLs.filter { $0 == url }.count
        emit(shouldConnect(url, count) ? .connected([:]) : .error(URLError(.cannotConnectToHost)))
    }

    func stop(closeCode _: UInt16) {}
    func forceStop() {}
    func emit(_ event: WebSocketEvent) { delegate?.didReceive(event: event) }
    func write(data: Data, opcode _: FrameOpCode, completion: (() -> Void)?) {
        guard let request = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = request["id"], let method = request["method"] as? String else { return }
        methods.append(method)
        let isSubscription = method == "chain_subscribeNewHeads"
        let response: [String: Any] = ["jsonrpc": "2.0", "id": id, "result": isSubscription ? "synthetic-subscription" : "synthetic-block-hash"]
        if let encoded = try? JSONSerialization.data(withJSONObject: response), let text = String(data: encoded, encoding: .utf8) {
            emit(.text(text))
        }
        if isSubscription {
            emit(.text(#"{"jsonrpc":"2.0","method":"chain_newHead","params":{"subscription":"synthetic-subscription","result":"synthetic-head"}}"#))
        }
        completion?()
    }

    func write(string: String, completion: (() -> Void)?) {
        write(data: Data(string.utf8), opcode: .textFrame, completion: completion)
    }
}

private final class PendingMutationAuthority: JSONRPCWriteAuthorizing {
    func authorize(_: () throws -> Void) throws {
        XCTFail("A pending request must not reach signing or transport authorization")
        throw JSONRPCEngineError.requestNotSent
    }
}
