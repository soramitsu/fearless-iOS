import Foundation
import Network
import XCTest
@testable import SSFUtils
import Starscream

final class AuthorizedRPCFailoverTests: XCTestCase {
    func testRetryDelegateReplacesURLWithoutDeadlockAndResumesPendingRead() throws {
        let endpoint = try LocalHandshakeEndpoint(test: self)
        defer { endpoint.close() }
        let h = FailoverHarness()
        let rotated = expectation(description: "delegate returned from replacement")
        let cancelled = expectation(description: "pending mutation is not replayed")
        let delegate = FailoverDelegate { engine, state in
            guard case .waitingReconnection = state else { return }
            engine.reconnect(url: endpoint.url)
            rotated.fulfill()
        }
        h.rpc.delegate = delegate
        h.rpc.mutex.lock(); h.rpc.changeState(.connecting(attempt: 7)); h.rpc.mutex.unlock()
        let readID: UInt16 = try h.rpc.callMethod("system_health", params: [String](), options: JSONRPCOptions(),
                                                completion: nil as ((Result<String, Error>) -> Void)?)
        let _: UInt16 = try h.rpc.callMethod("author_submitExtrinsic", params: ["signed-fixture"],
                                            options: JSONRPCOptions(writeAuthorization: FailoverAuthority())) {
            (result: Result<String, Error>) in
            guard case .failure(let error) = result else { return XCTFail("mutation must be cancelled") }
            XCTAssertEqual(error as? JSONRPCEngineError, .requestNotSent)
            cancelled.fulfill()
        }
        // This is the real delegate path that used to recursively acquire the
        // nonrecursive request mutex when the retry threshold rotated the URL.
        h.rpc.didReceive(event: .disconnected("fixture outage", 0), client: h.socket)
        wait(for: [rotated, cancelled, endpoint.handshakeReceived], timeout: 3)
        h.rpc.mutex.lock()
        XCTAssertEqual(h.rpc.url, endpoint.url)
        XCTAssertEqual(h.rpc.pendingRequests.map(\.requestId), [readID])
        XCTAssertTrue(h.rpc.inProgressRequests.isEmpty)
        if case .connecting = h.rpc.state {} else { XCTFail("new endpoint must finish its handshake") }
        h.rpc.mutex.unlock()
        // No future RPC was needed to open and handshake the replacement TCP
        // connection. The server deliberately does not accept the upgrade.
    }

    func testDormantURLReplacementWaitsForExplicitConnect() throws {
        let endpoint = try LocalHandshakeEndpoint(test: self)
        defer { endpoint.close() }
        let h = FailoverHarness()
        h.rpc.reconnect(url: endpoint.url)
        h.rpc.mutex.lock()
        if case .notConnected = h.rpc.state {} else { XCTFail("dormant engine started unexpectedly") }
        h.rpc.mutex.unlock()
        h.rpc.connectIfNeeded()
        wait(for: [endpoint.handshakeReceived], timeout: 3)
    }

    func testStateDelegateCanEnqueueRequestWithoutRecursiveMutex() {
        let h = FailoverHarness()
        let called = expectation(description: "delegate queued read")
        let delegate = FailoverDelegate { engine, state in
            guard case .connected = state else { return }
            do {
                let _: UInt16 = try engine.callMethod("system_health", params: [String](), options: JSONRPCOptions(),
                                                      completion: nil as ((Result<String, Error>) -> Void)?)
                called.fulfill()
            } catch { XCTFail("unexpected enqueue error: \(error)") }
        }
        h.rpc.delegate = delegate
        h.rpc.didReceive(event: .connected([:]), client: h.socket)
        wait(for: [called], timeout: 3)
    }

    func testAlreadyQueuedRetryCannotReconnectAfterExplicitDisconnect() {
        let h = FailoverHarness()
        h.rpc.mutex.lock(); h.rpc.changeState(.waitingReconnection(attempt: 7)); h.rpc.mutex.unlock()
        h.rpc.disconnectIfNeeded()
        h.rpc.didTrigger(scheduler: h.rpc.reconnectionScheduler)
        XCTAssertEqual(h.engine.starts, 0)
        h.rpc.mutex.lock()
        if case .notConnected = h.rpc.state {} else { XCTFail("cancelled timer restarted connection") }
        h.rpc.mutex.unlock()
    }

    func testStaleAuthorizationCannotCancelReusedPendingIdentifier() {
        let h = FailoverHarness()
        let old = FailoverAuthority(), current = FailoverAuthority()
        let done = expectation(description: "only matching authority cancels")
        let request = JSONRPCRequest(requestId: 42, data: Data(), options: JSONRPCOptions(writeAuthorization: current),
                                     responseHandler: FailoverHandler { error in
            XCTAssertEqual(error as? JSONRPCEngineError, .requestNotSent); done.fulfill()
        })
        h.rpc.mutex.lock()
        h.rpc.changeState(.connecting(attempt: 0))
        h.rpc.updateConnectionForRequest(request)
        h.rpc.mutex.unlock()
        h.rpc.cancelForIdentifier(42, writeAuthorization: old)
        h.rpc.mutex.lock(); XCTAssertEqual(h.rpc.pendingRequests.count, 1); h.rpc.mutex.unlock()
        h.rpc.cancelForIdentifier(42, writeAuthorization: current)
        wait(for: [done], timeout: 3)
        h.rpc.mutex.lock(); XCTAssertTrue(h.rpc.pendingRequests.isEmpty); h.rpc.mutex.unlock()
    }

    func testAllocatorExcludesActiveSubscriptionsAndRejectsExhaustion() throws {
        let h = FailoverHarness()
        for id in UInt16(1) ... UInt16.max where id != 42 {
            h.rpc.addSubscription(JSONRPCSubscription<String>(requestId: id, requestData: Data(),
                requestOptions: JSONRPCOptions(), updateClosure: { _ in }, failureClosure: { _, _ in }))
        }
        XCTAssertEqual(h.rpc.generateRequestId(), 42)
        h.rpc.addSubscription(JSONRPCSubscription<String>(requestId: 42, requestData: Data(),
            requestOptions: JSONRPCOptions(), updateClosure: { _ in }, failureClosure: { _, _ in }))
        XCTAssertEqual(h.rpc.generateRequestId(), 0)
        XCTAssertThrowsError(try h.rpc.callMethod("system_health", params: [String](), options: JSONRPCOptions(),
                                                completion: nil as ((Result<String, Error>) -> Void)?)) {
            XCTAssertEqual($0 as? JSONRPCEngineError, .unknownError)
        }
        XCTAssertTrue(h.rpc.pendingRequests.isEmpty)
    }

    func testSupersededRetryNotificationDoesNotRotateConnectedOrDisconnectedEngine() {
        for disconnect in [false, true] {
            let queue = DispatchQueue(label: "test.fearless.blocked-state")
            let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
            queue.async { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
            XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
            let h = FailoverHarness(queue: queue)
            let latest = expectation(description: "only latest state reaches delegate")
            let delegate = FailoverDelegate { _, state in
                if disconnect, case .notConnected = state { latest.fulfill() }
                else if !disconnect, case .connected = state { latest.fulfill() }
                else { XCTFail("superseded state escaped queued freshness check") }
            }
            h.rpc.delegate = delegate
            h.rpc.mutex.lock()
            h.rpc.changeState(.waitingReconnection(attempt: 7))
            h.rpc.changeState(.connected)
            h.rpc.mutex.unlock()
            if disconnect { h.rpc.disconnectIfNeeded() }
            release.signal()
            wait(for: [latest], timeout: 3)
            h.rpc.delegate = nil
        }
    }

    func testStateDelegatesRemainSerialWithConcurrentProcessingQueue() {
        let h = FailoverHarness(queue: DispatchQueue(label: "test.fearless.concurrent-state", attributes: .concurrent))
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0), second = DispatchSemaphore(value: 0)
        let done = expectation(description: "second callback follows first")
        let delegate = FailoverDelegate { _, state in
            switch state {
            case .connecting:
                entered.signal()
                XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            case .connected:
                second.signal(); done.fulfill()
            default: break
            }
        }
        h.rpc.delegate = delegate
        h.rpc.mutex.lock(); h.rpc.changeState(.connecting(attempt: 0)); h.rpc.mutex.unlock()
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        h.rpc.mutex.lock(); h.rpc.changeState(.connected); h.rpc.mutex.unlock()
        XCTAssertEqual(second.wait(timeout: .now() + 0.05), .timedOut)
        release.signal()
        wait(for: [done], timeout: 3)
    }

    func testEachReplacementCreatesFreshFixtureAndPreservesPendingLegacyRead() throws {
        let h = FailoverHarness()
        var sockets = [Starscream.WebSocket]()
        h.rpc.replacementConnectionFactory = { request in
            let socket = Starscream.WebSocket(request: request, engine: FailoverEngine())
            sockets.append(socket)
            return socket
        }
        h.rpc.mutex.lock(); h.rpc.changeState(.connecting(attempt: 0)); h.rpc.mutex.unlock()
        let id: UInt16 = try h.rpc.callMethod("system_health", params: [String](), options: JSONRPCOptions(),
                                            completion: nil as ((Result<String, Error>) -> Void)?)
        let urls = [URL(string: "ws://127.0.0.1:10")!, URL(string: "ws://127.0.0.1:11")!]
        for url in urls { h.rpc.reconnect(url: url) }
        XCTAssertEqual(sockets.map { $0.request.url! }, urls)
        XCTAssertFalse(sockets[0] === sockets[1])
        XCTAssertNil(sockets[0].delegate)
        XCTAssertTrue(sockets[1].delegate === h.rpc)
        XCTAssertTrue(sockets[1].callbackQueue === h.rpc.completionQueue)
        XCTAssertEqual(sockets.compactMap { ($0.engine as? FailoverEngine)?.starts }, [1, 1])
        h.rpc.mutex.lock()
        XCTAssertEqual(h.rpc.pendingRequests.map(\.requestId), [id])
        h.rpc.mutex.unlock()
    }

    func testPublicReservationCannotBeAllocatedToRPCBeforeWatcherRegisters() throws {
        let h = FailoverHarness()
        for id in UInt16(1) ... UInt16.max where id != 42 && id != 43 {
            h.rpc.addSubscription(makeWatcher(id))
        }
        let watcherID = h.rpc.generateRequestId()
        XCTAssertTrue([42, 43].contains(watcherID))
        h.rpc.mutex.lock(); h.rpc.changeState(.connecting(attempt: 0)); h.rpc.mutex.unlock()
        let cancelled = expectation(description: "only guarded RPC is cancelled")
        let authority = FailoverAuthority()
        let rpcID: UInt16 = try h.rpc.callMethod("author_submitExtrinsic", params: ["fixture"],
            options: JSONRPCOptions(writeAuthorization: authority)) { (result: Result<String, Error>) in
            guard case .failure(let error) = result else { return XCTFail("expected cancellation") }
            XCTAssertEqual(error as? JSONRPCEngineError, .requestNotSent); cancelled.fulfill()
        }
        XCTAssertNotEqual(rpcID, watcherID)
        XCTAssertEqual(Set([rpcID, watcherID]), Set([UInt16(42), UInt16(43)]))
        let watcher = makeWatcher(watcherID)
        h.rpc.addSubscription(watcher)
        XCTAssertEqual(h.rpc.generateRequestId(), 0)
        h.rpc.cancelForIdentifier(rpcID, writeAuthorization: authority)
        wait(for: [cancelled], timeout: 3)
        h.rpc.mutex.lock()
        XCTAssertTrue(h.rpc.subscriptions[watcherID] === watcher)
        XCTAssertTrue(h.rpc.pendingRequests.isEmpty)
        h.rpc.mutex.unlock()
        XCTAssertEqual(h.rpc.generateRequestId(), rpcID)
    }

    func testConcurrentReservationsRegistrationAndRPCAllocationRemainDistinct() {
        let h = FailoverHarness()
        let lock = NSLock()
        var identifiers = [UInt16](), rpcIdentifiers = [UInt16]()
        DispatchQueue.concurrentPerform(iterations: 128) { _ in
            let identifier = h.rpc.generateRequestId()
            lock.lock(); identifiers.append(identifier); lock.unlock()
        }
        XCTAssertEqual(Set(identifiers).count, 128)
        XCTAssertFalse(identifiers.contains(0))
        h.rpc.mutex.lock(); h.rpc.changeState(.connecting(attempt: 0)); h.rpc.mutex.unlock()
        DispatchQueue.concurrentPerform(iterations: 128) { index in
            do {
                let id: UInt16 = try h.rpc.callMethod("system_health", params: [String](), options: JSONRPCOptions(),
                                                    completion: nil as ((Result<String, Error>) -> Void)?)
                lock.lock(); rpcIdentifiers.append(id); lock.unlock()
                h.rpc.addSubscription(makeWatcher(identifiers[index]))
            } catch { XCTFail("concurrent allocation failed: \(error)") }
        }
        XCTAssertEqual(Set(rpcIdentifiers).count, 128)
        XCTAssertTrue(Set(identifiers).isDisjoint(with: rpcIdentifiers))
        h.rpc.mutex.lock()
        XCTAssertEqual(Set(h.rpc.subscriptions.keys), Set(identifiers))
        XCTAssertEqual(Set(h.rpc.pendingRequests.map(\.requestId)), Set(rpcIdentifiers))
        h.rpc.mutex.unlock()
    }

    func testConflictingAndZeroSubscriptionRegistrationRejectsOnlyNewWatcher() {
        let h = FailoverHarness()
        let original = makeWatcher(42)
        h.rpc.addSubscription(original)
        h.rpc.addSubscription(original) // Idempotent registration is harmless.
        h.rpc.mutex.lock()
        h.rpc.changeState(.connecting(attempt: 0))
        h.rpc.updateConnectionForRequest(JSONRPCRequest(requestId: 100, data: Data(), options: JSONRPCOptions(), responseHandler: nil))
        h.rpc.send(request: JSONRPCRequest(requestId: 101, data: Data(), options: JSONRPCOptions(), responseHandler: nil))
        h.rpc.mutex.unlock()
        let rejected = expectation(description: "conflict rejected outside mutex")
        rejected.expectedFulfillmentCount = 4
        for id in [UInt16(0), 42, 100, 101] {
            h.rpc.addSubscription(JSONRPCSubscription<String>(requestId: id, requestData: Data(), requestOptions: JSONRPCOptions(),
                updateClosure: { _ in XCTFail("rejected watcher updated") }, failureClosure: { error, removed in
                    XCTAssertEqual(error as? JSONRPCEngineError, .unknownError)
                    XCTAssertTrue(removed)
                    XCTAssertNotEqual(h.rpc.generateRequestId(), 0) // No callback under engine mutex.
                    rejected.fulfill()
                }))
        }
        wait(for: [rejected], timeout: 3)
        h.rpc.mutex.lock()
        XCTAssertEqual(h.rpc.subscriptions.count, 1)
        XCTAssertTrue(h.rpc.subscriptions[42] === original)
        XCTAssertEqual(h.rpc.pendingRequests.map(\.requestId), [100])
        XCTAssertNotNil(h.rpc.inProgressRequests[101])
        h.rpc.mutex.unlock()
    }

    private func makeWatcher(_ identifier: UInt16) -> JSONRPCSubscription<String> {
        JSONRPCSubscription<String>(requestId: identifier, requestData: Data(), requestOptions: JSONRPCOptions(),
            updateClosure: { _ in }, failureClosure: { _, _ in XCTFail("existing watcher must not be removed") })
    }
}

private final class FailoverAuthority: JSONRPCWriteAuthorizing {
    func authorize(_ handoff: () throws -> Void) throws { try handoff() }
}
private final class FailoverHandler: JSONRPCResponseHandling {
    let error: (Error) -> Void
    init(_ error: @escaping (Error) -> Void) { self.error = error }
    func handle(data: Data) { XCTFail("unexpected response") }
    func handle(error: Error) { self.error(error) }
}
private final class FailoverDelegate: WebSocketEngineDelegate {
    let change: (WebSocketEngine, WebSocketEngine.State) -> Void
    init(_ change: @escaping (WebSocketEngine, WebSocketEngine.State) -> Void) { self.change = change }
    func webSocketDidChangeState(engine: WebSocketEngine, from oldState: WebSocketEngine.State, to newState: WebSocketEngine.State) {
        change(engine, newState)
    }
}
private final class FailoverReachability: ReachabilityManagerProtocol {
    var isReachable: Bool { true }
    func add(listener: ReachabilityListenerDelegate) throws {}
    func remove(listener: ReachabilityListenerDelegate) {}
}
private struct SlowReconnect: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt: Int) -> TimeInterval? { 60 }
}
private final class FailoverEngine: Engine {
    var starts = 0
    func register(delegate: EngineDelegate) {}
    func start(request: URLRequest) { starts += 1 }
    func stop(closeCode: UInt16) {}
    func forceStop() {}
    func write(data: Data, opcode: FrameOpCode, completion: (() -> Void)?) { completion?() }
    func write(string: String, completion: (() -> Void)?) { completion?() }
}
private final class FailoverHarness {
    let rpc: WebSocketEngine
    let socket: Starscream.WebSocket
    let engine = FailoverEngine()
    init(queue: DispatchQueue = DispatchQueue(label: "test.fearless.failover")) {
        let url = URL(string: "ws://127.0.0.1:9")!
        rpc = WebSocketEngine(connectionName: "fixture", url: url, reachabilityManager: FailoverReachability(),
                              reconnectionStrategy: SlowReconnect(), processingQueue: queue, autoconnect: false, pingInterval: 0)
        socket = Starscream.WebSocket(request: URLRequest(url: url), engine: engine)
        socket.callbackQueue = queue; socket.delegate = rpc
        rpc.connection = socket
    }
    deinit {
        rpc.delegate = nil
        rpc.disconnectIfNeeded()
        rpc.connection.delegate = nil
        rpc.connection.forceDisconnect()
    }
}

/// An actual loopback TCP peer records the replacement's HTTP upgrade request.
/// It intentionally never approves the handshake, so no RPC frame can be sent.
private final class LocalHandshakeEndpoint {
    let listener: NWListener
    let handshakeReceived: XCTestExpectation
    let url: URL
    private let queue = DispatchQueue(label: "test.fearless.failover.peer")
    private var peer: NWConnection?
    init(test: XCTestCase) throws {
        listener = try NWListener(using: .tcp, on: .any)
        handshakeReceived = test.expectation(description: "replacement starts a fresh HTTP handshake")
        let ready = test.expectation(description: "local listener ready")
        listener.newConnectionHandler = { peer in peer.cancel(); XCTFail("fixture connected before initialization") }
        listener.stateUpdateHandler = { state in if case .ready = state { ready.fulfill() } }
        listener.start(queue: queue)
        test.wait(for: [ready], timeout: 3)
        url = URL(string: "ws://127.0.0.1:\(try XCTUnwrap(listener.port).rawValue)")!
        listener.newConnectionHandler = { [weak self] peer in
            guard let self = self else { return }
            self.peer = peer
            peer.start(queue: self.queue)
            peer.receive(minimumIncompleteLength: 4, maximumLength: 4096) { [weak self] data, _, _, error in
                XCTAssertNil(error)
                XCTAssertTrue(String(data: data ?? Data(), encoding: .utf8)?.hasPrefix("GET ") == true)
                self?.handshakeReceived.fulfill()
            }
        }
    }
    func close() { queue.sync { peer?.cancel(); listener.cancel() } }
}
