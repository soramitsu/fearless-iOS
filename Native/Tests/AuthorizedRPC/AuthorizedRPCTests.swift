import Foundation
import XCTest
@testable import SSFUtils
@testable import Starscream

final class AuthorizedRPCTests: XCTestCase {
    func testGuardedOptionsNeverResendAndLegacyDefaultsRemain() {
        let authority = RPCGuard()
        let guarded = JSONRPCOptions(writeAuthorization: authority)
        XCTAssertFalse(guarded.resendOnReconnect)
        XCTAssertTrue(guarded.writeAuthorization === authority)
        XCTAssertTrue(JSONRPCOptions().resendOnReconnect)
        XCTAssertFalse(JSONRPCOptions(resendOnReconnect: false).resendOnReconnect)
        XCTAssertNil(JSONRPCOptions().writeAuthorization)
    }

    func testDeniedWriterNeverSendsRequest() throws {
        let h = NetworkHarness()
        let done = expectation(description: "denied")
        _ = try h.call(guarded: RPCGuard { _ in throw ContractError.denied }) { result in
            XCTAssertEqual(result.error as? ContractError, .denied); done.fulfill()
        }
        wait(for: [done], timeout: 3)
        XCTAssertTrue(h.transport.sent.isEmpty)
    }

    func testExpiryDuringFramePreparationPreventsSubmission() throws {
        let h = NetworkHarness()
        var valid = true
        h.framer.beforeFrame = { valid = false }
        let done = expectation(description: "expired")
        _ = try h.call(guarded: RPCGuard { handoff in
            guard valid else { throw ContractError.denied }; try handoff()
        }) { result in XCTAssertEqual(result.error as? ContractError, .denied); done.fulfill() }
        wait(for: [done], timeout: 3)
        XCTAssertTrue(h.transport.sent.isEmpty)
    }

    func testCancelQueuedRequestPreventsBytes() throws {
        let h = NetworkHarness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        h.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let done = expectation(description: "not sent")
        let id = try h.call { result in
            XCTAssertEqual(result.error as? JSONRPCEngineError, .requestNotSent); done.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        h.rpc.cancelForIdentifier(id)
        wait(for: [done], timeout: 3)
        release.signal()
        h.drain()
        XCTAssertTrue(h.transport.sent.isEmpty)
    }

    func testCancelDequeuedRequestWaitingOnAuthorityPreventsBytes() throws {
        let h = NetworkHarness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let done = expectation(description: "cancelled during authority wait")
        let id = try h.call(guarded: RPCGuard { handoff in
            entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            try handoff()
        }) { result in
            XCTAssertEqual(result.error as? JSONRPCEngineError, .requestNotSent); done.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        h.rpc.cancelForIdentifier(id)
        wait(for: [done], timeout: 3)
        release.signal()
        h.drain()
        XCTAssertTrue(h.transport.sent.isEmpty)
    }

    func testAcceptedRequestCancelledWithoutResponseIsUnknown() throws {
        let h = NetworkHarness()
        let sent = expectation(description: "handed off")
        h.transport.onSend = { sent.fulfill() }
        let done = expectation(description: "unknown")
        let id = try h.call { result in
            XCTAssertEqual(result.error as? JSONRPCEngineError, .submissionOutcomeUnknown); done.fulfill()
        }
        wait(for: [sent], timeout: 3)
        h.rpc.cancelForIdentifier(id)
        wait(for: [done], timeout: 3)
        XCTAssertEqual(h.transport.sent.count, 1)
    }

    func testReconnectDoesNotReplayGuardedRequestButKeepsLegacyRead() throws {
        let h = NetworkHarness()
        let sent = expectation(description: "accepted")
        h.transport.onSend = { sent.fulfill() }
        let unknown = expectation(description: "unknown")
        _ = try h.call { result in
            XCTAssertEqual(result.error as? JSONRPCEngineError, .submissionOutcomeUnknown); unknown.fulfill()
        }
        wait(for: [sent], timeout: 3)
        let _: UInt16 = try h.rpc.callMethod("system_health", params: [String](), options: JSONRPCOptions(), completion: nil as ((Result<String, Error>) -> Void)?)
        h.rpc.mutex.lock()
        _ = h.rpc.resetInProgress()
        let pending = h.rpc.pendingEngineRequests
        h.rpc.mutex.unlock()
        wait(for: [unknown], timeout: 3)
        XCTAssertEqual(pending.count, 1)
        XCTAssertNil(pending.first?.options.writeAuthorization)
        h.rpc.mutex.lock(); h.rpc.sendAllPendingRequests(); h.rpc.mutex.unlock()
        h.drain()
        XCTAssertEqual(h.transport.sent.count, 1)
    }

    func testURLReplacementCancelsQueuedMutationAndRequiresNewEngine() throws {
        let h = NetworkHarness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        h.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let cancelled = expectation(description: "old endpoint request cancelled")
        _ = try h.call { result in
            XCTAssertEqual(result.error as? JSONRPCEngineError, .requestNotSent); cancelled.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let nextURL = URL(string: "ws://127.0.0.1:9")!
        h.rpc.reconnect(url: nextURL)
        wait(for: [cancelled], timeout: 3)
        let replacementWriter = try XCTUnwrap(h.rpc.connection.engine as? WSEngine)
        XCTAssertFalse(replacementWriter === h.writer)
        XCTAssertEqual((h.rpc.connection as? WebSocket)?.request.url, nextURL)
        XCTAssertTrue(h.rpc.connection.callbackQueue === h.queue)
        XCTAssertFalse({ if case .connected = h.rpc.state { return true }; return false }(),
                       "replacement endpoint must complete its own handshake")
        // The old writer is stopped after replacement; a legacy write is no
        // longer a valid queue barrier on that closed writer. Reuse only this
        // detached fixture to prove the cancelled old frame also stays denied
        // if its engine becomes writable again before frame preparation ends.
        h.writer.start(request: h.socket.request)
        h.writer.didReceiveHTTP(event: .success([:]))
        release.signal(); h.drain()
        XCTAssertTrue(h.transport.sent.isEmpty)
    }

    func testLatePreviousSocketEventCannotSettleCurrentRequest() {
        let h = NetworkHarness()
        h.rpc.reconnect(url: URL(string: "ws://127.0.0.1:9")!)
        let failed = expectation(description: "only explicit cancellation settles current request")
        let current = JSONRPCRequest(requestId: 42, data: Data(), options: JSONRPCOptions(),
            responseHandler: Handler(data: { _ in XCTFail("old socket completed new request") }, error: { _ in failed.fulfill() }))
        // Register an in-progress request on the inactive new writer; no
        // external connection opens. An old socket's matching ID must be ignored.
        h.rpc.mutex.lock(); h.rpc.send(request: current); h.rpc.mutex.unlock()
        h.respond(42, value: "old-socket-response")
        XCTAssertNotNil(h.rpc.inProgressRequests[42])
        h.rpc.didReceive(event: .connected([:]), client: h.socket)
        XCTAssertFalse({ if case .connected = h.rpc.state { return true }; return false }(),
                       "old socket activated new endpoint")
        h.rpc.cancelForIdentifier(42)
        wait(for: [failed], timeout: 3)
    }

    func testPendingGuardedRequestIsCancelledOnFailedInitialConnection() throws {
        let h = NetworkHarness(connected: false)
        let done = expectation(description: "initial connection failed")
        _ = try h.call { result in
            XCTAssertEqual(result.error as? JSONRPCEngineError, .requestNotSent); done.fulfill()
        }
        h.rpc.mutex.lock()
        h.rpc.scheduleReconnectionOrDisconnect(1)
        h.rpc.mutex.unlock()
        wait(for: [done], timeout: 3)
        XCTAssertTrue(h.rpc.pendingEngineRequests.isEmpty)
        XCTAssertTrue(h.transport.sent.isEmpty)
    }

    func testPrematureRemoteResponseCannotCompleteUnsentRequest() throws {
        let h = NetworkHarness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        h.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let done = expectation(description: "unsent remote response rejected")
        let id = try h.call { result in
            XCTAssertEqual(result.error as? JSONRPCEngineError, .requestNotSent); done.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        h.respond(id, value: "unearned-result")
        wait(for: [done], timeout: 3)
        release.signal(); h.drain()
        XCTAssertTrue(h.transport.sent.isEmpty)
    }

    func testDelayedOldTransportFailureCannotCancelReusedRequestID() throws {
        let h = NetworkHarness()
        let blocked = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        h.queue.async { blocked.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        XCTAssertEqual(blocked.wait(timeout: .now() + 3), .success)
        let old = expectation(description: "old cancellation")
        let request = JSONRPCRequest(requestId: 42, data: Data("old".utf8), options: JSONRPCOptions(writeAuthorization: RPCGuard { _ in throw ContractError.denied }),
                                     responseHandler: Handler { error in XCTAssertEqual(error as? JSONRPCEngineError, .requestNotSent); old.fulfill() })
        h.rpc.mutex.lock(); h.rpc.send(request: request); h.rpc.mutex.unlock()
        h.rpc.cancelForIdentifier(42)
        let sent = expectation(description: "new accepted")
        h.transport.onSend = { sent.fulfill() }
        let result = expectation(description: "new request survives old callback")
        let current = JSONRPCRequest(requestId: 42, data: Data("new".utf8), options: JSONRPCOptions(writeAuthorization: RPCGuard()),
                                     responseHandler: Handler(data: { _ in result.fulfill() }, error: { _ in XCTFail("new request cancelled") }))
        h.rpc.mutex.lock(); h.rpc.send(request: current); h.rpc.mutex.unlock()
        release.signal()
        wait(for: [old, sent], timeout: 3)
        h.queue.sync {} // drain the delayed old transport callback
        h.respond(42, value: "accepted")
        wait(for: [result], timeout: 3)
        XCTAssertEqual(h.transport.sent, [Data("new".utf8)])
    }

    func testFailureCallbackCanReenterEngine() throws {
        let h = NetworkHarness()
        let done = expectation(description: "reentrant callback")
        _ = try h.call(guarded: RPCGuard { _ in throw ContractError.denied }) { _ in
            h.rpc.cancelForIdentifier(999); done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }

    func testGuardedSubscriptionIsRemovedInsteadOfRescheduled() {
        let h = NetworkHarness()
        let done = expectation(description: "subscription uncertainty")
        let guarded = JSONRPCSubscription<String>(requestId: 10, requestData: Data(), requestOptions: JSONRPCOptions(writeAuthorization: RPCGuard()),
            updateClosure: { _ in }, failureClosure: { error, removed in
                XCTAssertEqual(error as? JSONRPCEngineError, .submissionOutcomeUnknown); XCTAssertTrue(removed); done.fulfill()
            })
        guarded.remoteId = "old-subscription"
        h.rpc.addSubscription(guarded)
        h.rpc.mutex.lock(); h.rpc.rescheduleActiveSubscriptions(); h.rpc.mutex.unlock()
        wait(for: [done], timeout: 3)
        XCTAssertTrue(h.rpc.pendingEngineRequests.isEmpty)
        XCTAssertNil(h.rpc.subscriptions[10])
    }

    func testValidUnsubscribeQueuesWithoutRecursiveEngineLock() {
        let h = NetworkHarness()
        let request = Data("{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"state_subscribeStorage\",\"params\":[[]]}".utf8)
        let subscription = JSONRPCSubscription<String>(requestId: 10, requestData: request, requestOptions: JSONRPCOptions(),
            updateClosure: { _ in }, failureClosure: { _, _ in })
        h.rpc.addSubscription(subscription)
        let done = expectation(description: "unsubscribe returns")
        DispatchQueue.global().async {
            do { try h.rpc.unsubsribe(10) } catch { XCTFail("valid unsubscribe failed") }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        h.drain()
    }

    func testMalformedUnsubscribeDoesNotKeepEngineMutexLocked() throws {
        let h = NetworkHarness()
        let subscription = JSONRPCSubscription<String>(requestId: 10, requestData: Data("invalid-json".utf8), requestOptions: JSONRPCOptions(),
            updateClosure: { _ in }, failureClosure: { _, _ in })
        h.rpc.addSubscription(subscription)
        XCTAssertThrowsError(try h.rpc.unsubsribe(10))
        XCTAssertTrue(h.rpc.mutex.try())
        h.rpc.mutex.unlock()
    }
}

private enum ContractError: Error { case denied }
private extension Result where Success == String, Failure == Error {
    var error: Error? { if case .failure(let error) = self { return error }; return nil }
}
final class RPCGuard: JSONRPCWriteAuthorizing {
    let action: (() throws -> Void) throws -> Void
    init(_ action: @escaping (() throws -> Void) throws -> Void = { try $0() }) { self.action = action }
    func authorize(_ handoff: () throws -> Void) throws { try action(handoff) }
}
private final class Handler: JSONRPCResponseHandling {
    let onData: (Data) -> Void
    let onError: (Error) -> Void
    init(data: @escaping (Data) -> Void = { _ in XCTFail("unexpected data") }, error: @escaping (Error) -> Void) { onData = data; onError = error }
    func handle(data: Data) { onData(data) }
    func handle(error: Error) { onError(error) }
}
private final class Reachable: ReachabilityManagerProtocol {
    var isReachable = true
    func add(listener: ReachabilityListenerDelegate) throws {}
    func remove(listener: ReachabilityListenerDelegate) {}
}
final class Ready: WebSocketEngineDelegate {
    let signal = DispatchSemaphore(value: 0)
    func webSocketDidChangeState(engine: WebSocketEngine, from oldState: WebSocketEngine.State, to newState: WebSocketEngine.State) {
        if case .connected = newState { signal.signal() }
    }
}
private final class HeaderChecker: HeaderValidator {
    func validate(headers: [String: String], key: String) -> Error? { nil }
}
final class ContractFramer: Framer {
    var beforeFrame: (() -> Void)?
    func add(data: Data) {}
    func register(delegate: FramerEventClient) {}
    func createWriteFrame(opcode: FrameOpCode, payload: Data, isCompressed: Bool) -> Data { if opcode == .textFrame { beforeFrame?() }; return payload }
    func updateCompression(supports: Bool) {}
    func supportsCompression() -> Bool { false }
}
final class ContractTransport: AuthorizedTransport {
    let context = NSObject()
    private let lock = NSLock()
    private var frames = [Data]()
    var onSend: (() -> Void)?
    var sent: [Data] { lock.lock(); defer { lock.unlock() }; return frames }
    var usingTLS: Bool { false }
    func register(delegate: TransportEventClient) {}
    func connect(url: URL, timeout: Double, certificatePinning: CertificatePinning?) {}
    func disconnect() {}
    func captureWriteContext() -> AnyObject? { context }
    func write(data: Data, completion: @escaping (Error?) -> Void) { completion(nil) }
    func write(data: Data, context: AnyObject, operation: AuthorizedWrite, authorization: WebSocketWriteAuthorizing, completion: @escaping (Error?) -> Void) throws {
        lock.lock()
        let before = frames.count
        operation.perform(authorization: authorization) { frames.append(data); completion(nil) }
        let didSend = frames.count != before
        lock.unlock()
        if didSend { onSend?() }
    }
}
final class NetworkHarness {
    let queue = DispatchQueue(label: "test.fearless.rpc.callbacks")
    let transport = ContractTransport()
    let framer = ContractFramer()
    let ready = Ready()
    let rpc: WebSocketEngine
    let socket: WebSocket
    let writer: WSEngine
    init(connected: Bool = true) {
        let url = URL(string: "wss://example.invalid")!
        rpc = WebSocketEngine(connectionName: "fixture", url: url, reachabilityManager: Reachable(), processingQueue: queue, autoconnect: false, pingInterval: 0)
        writer = WSEngine(transport: transport, headerValidator: HeaderChecker(), framer: framer)
        socket = WebSocket(request: URLRequest(url: url), engine: writer)
        socket.callbackQueue = queue
        socket.delegate = rpc
        rpc.connection = socket
        rpc.delegate = ready
        if connected {
            rpc.connectIfNeeded()
            writer.didReceiveHTTP(event: .success([:]))
            XCTAssertEqual(ready.signal.wait(timeout: .now() + 3), .success)
        }
    }
    deinit { socket.delegate = nil; socket.forceDisconnect() }
    func call(guarded: JSONRPCWriteAuthorizing = RPCGuard(), completion: @escaping (Result<String, Error>) -> Void) throws -> UInt16 {
        try rpc.callMethod("author_submitExtrinsic", params: ["immutable-signed-fixture"], options: JSONRPCOptions(writeAuthorization: guarded), completion: completion)
    }
    func respond(_ id: UInt16, value: String) {
        rpc.didReceive(event: .text("{\"jsonrpc\":\"2.0\",\"id\":\(id),\"result\":\"\(value)\"}"), client: socket)
    }
    func drain() {
        let drained = DispatchSemaphore(value: 0)
        writer.write(data: Data(), opcode: .pong) { drained.signal() }
        XCTAssertEqual(drained.wait(timeout: .now() + 3), .success)
    }
}
