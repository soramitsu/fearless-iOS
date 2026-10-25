#if canImport(Network)
import Foundation
import Network
import XCTest
@testable import Starscream

final class TCPGenerationTests: XCTestCase {
    func testActualTCPReceiveLoopReconnectsOnSameTransport() throws {
        let h = try TCPGenerationHarness(test: self, mockReads: false)
        defer { h.close() }
        _ = try h.connect()
        let oldPeer = h.peer
        oldPeer.send(content: Data("old-message".utf8), completion: .contentProcessed { XCTAssertNil($0) })
        func waitForBytes(_ count: Int) {
            let deadline = DispatchTime.now() + 3
            while h.sink.data.reduce(0, { $0 + $1.count }) < count {
                guard h.sink.received.wait(timeout: deadline) == .success else { return XCTFail("TCP payload incomplete") }
            }
        }
        waitForBytes("old-message".utf8.count)
        let current = try h.connect()
        oldPeer.send(content: Data("obsolete-message".utf8), completion: .contentProcessed { _ in })
        h.peer.send(content: Data("current-message".utf8), completion: .contentProcessed { XCTAssertNil($0) })
        waitForBytes("old-messagecurrent-message".utf8.count)
        XCTAssertEqual(Data(h.sink.data.joined()), Data("old-messagecurrent-message".utf8))
        XCTAssertTrue(h.transport.captureWriteContext() === current)
    }

    func testRetiredStateReadViabilityAndPathCallbacksCannotAffectReplacement() throws {
        let h = try TCPGenerationHarness(test: self)
        defer { h.close() }
        let old = try h.connect()
        let read = try XCTUnwrap(h.reads.last)
        let state = old.connection.stateUpdateHandler
        let viability = old.connection.viabilityUpdateHandler
        let path = old.connection.betterPathUpdateHandler
        let current = try h.connect()
        let before = h.sink.count, readCount = h.reads.count
        for update: NWConnection.State in [.ready, .waiting(.posix(.ETIMEDOUT)), .cancelled, .failed(.posix(.ECONNRESET))] {
            state?(update)
        }
        viability?(false); path?(true)
        read(Data("old-reply".utf8), false, nil)
        XCTAssertEqual(h.sink.count, before)
        XCTAssertEqual(h.reads.count, readCount)
        XCTAssertTrue(h.transport.captureWriteContext() === current)
        let received = expectation(description: "replacement receives only current write")
        let bytes = Data("current-generation".utf8)
        h.peer.receive(minimumIncompleteLength: bytes.count, maximumLength: bytes.count) { data, _, _, error in
            XCTAssertNil(error); XCTAssertEqual(data, bytes); received.fulfill()
        }
        h.transport.write(data: bytes) { XCTAssertNil($0) }
        wait(for: [received], timeout: 3)
    }

    func testDisconnectRetiresReadLoopAndCannotRestoreWriteContext() throws {
        let h = try TCPGenerationHarness(test: self)
        defer { h.close() }
        let old = try h.connect()
        let read = try XCTUnwrap(h.reads.last)
        h.transport.disconnect()
        let before = h.sink.count, readCount = h.reads.count
        h.transport.handleState(.ready, context: old)
        read(Data([1, 2]), false, nil)
        XCTAssertNil(h.transport.captureWriteContext())
        XCTAssertEqual(h.sink.count, before)
        XCTAssertEqual(h.reads.count, readCount)
    }

    func testRetiredTLSVerificationCompletesExactlyOnceWithoutObsoleteFailure() throws {
        let h = try TCPGenerationHarness(test: self)
        defer { h.close() }
        let old = try h.connect()
        _ = try h.connect()
        let before = h.sink.count
        var decisions = [Bool]()
        let completion = TCPTransport.TLSCompletion { decisions.append($0) }
        h.transport.finishVerification(.failed(nil), generation: old.generation, completion: completion)
        h.transport.finishVerification(.success, generation: old.generation, completion: completion)
        XCTAssertEqual(decisions, [false])
        XCTAssertEqual(h.sink.count, before)
    }

    func testCurrentTLSVerificationPreservesSuccessAndFailure() throws {
        let h = try TCPGenerationHarness(test: self)
        defer { h.close() }
        let current = try h.connect()
        var decisions = [Bool]()
        let success = TCPTransport.TLSCompletion { decisions.append($0) }
        h.transport.finishVerification(.success, generation: current.generation, completion: success)
        h.transport.finishVerification(.failed(nil), generation: current.generation, completion: success)
        XCTAssertEqual(h.sink.failures, 0)
        h.transport.finishVerification(.failed(nil), generation: current.generation,
            completion: TCPTransport.TLSCompletion { decisions.append($0) })
        XCTAssertEqual(decisions, [true, false])
        XCTAssertEqual(h.sink.failures, 1)
    }

    func testReconnectWaitsForAlreadyAdmittedCallbackAndRejectsItsContinuation() throws {
        let h = try TCPGenerationHarness(test: self)
        defer { h.close() }
        _ = try h.connect()
        let read = try XCTUnwrap(h.reads.last)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        h.sink.onRead = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let received = expectation(description: "already admitted callback finishes")
        DispatchQueue.global().async { read(Data([1, 2]), false, nil); received.fulfill() }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let replaced = DispatchSemaphore(value: 0)
        DispatchQueue.global().async { h.transport.connect(url: h.url); replaced.signal() }
        XCTAssertEqual(replaced.wait(timeout: .now() + 0.05), .timedOut)
        release.signal()
        wait(for: [received], timeout: 3)
        XCTAssertEqual(replaced.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(h.sink.connected.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(h.accepted.wait(timeout: .now() + 3), .success)
        h.sink.onRead = nil
        let before = h.sink.count, readCount = h.reads.count
        read(Data([3, 4]), false, nil)
        XCTAssertEqual(h.sink.count, before)
        XCTAssertEqual(h.reads.count, readCount)
    }

    func testBlockedEventCallbackDoesNotAddWriterWaitAfterAuthorization() throws {
        let h = try TCPGenerationHarness(test: self)
        defer { h.close() }
        let current = try h.connect(), read = try XCTUnwrap(h.reads.last)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        h.sink.onRead = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let callbackDone = expectation(description: "blocked event finished")
        DispatchQueue.global().async { read(Data([1, 2]), true, nil); callbackDone.fulfill() }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let sent = expectation(description: "writer does not acquire event lock")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            if case .failure(let error) = result { XCTFail("unexpected write failure: \(error)") }
            sent.fulfill()
        }
        try h.transport.write(data: Data([7, 8]), context: current, operation: operation,
            authorization: GenerationAuthority { try $0() }) { error in
                operation.complete(error.map { .failure($0) } ?? .success(()))
            }
        wait(for: [sent], timeout: 3)
        release.signal()
        wait(for: [callbackDone], timeout: 3)
    }

    func testDeferredOldHTTPAndFrameCallbacksCannotActivateOrPublishOnNewSession() {
        let h = EngineGenerationHarness()
        h.start()
        let oldHTTP = h.http.delegate!, oldFrame = h.framer.delegate!
        oldHTTP.didReceiveHTTP(event: .success([:]))
        h.engine.forceStop(); h.start()
        oldHTTP.didReceiveHTTP(event: .success([:]))
        oldFrame.frameProcessed(event: .frame(frame("old")))
        XCTAssertEqual(h.events.connected, 1)
        XCTAssertTrue(h.events.text.isEmpty)
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        h.framer.delegate?.frameProcessed(event: .frame(frame("current")))
        XCTAssertEqual(h.events.connected, 2)
        XCTAssertEqual(h.events.text, ["current"])
    }

    func testQueuedFramerRetainsOriginalDelegateAndResetsPartialBytes() {
        let framer = WSFramer(), server = WSFramer(isServer: true)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let old = FrameRecorder(), current = FrameRecorder()
        let done = expectation(description: "new frame decoded independently")
        old.onFrame = { data in if data == Data([1]) { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) } }
        current.onFrame = { data in XCTAssertEqual(data, Data([9])); done.fulfill() }
        framer.register(delegate: old)
        framer.add(data: server.createWriteFrame(opcode: .binaryFrame, payload: Data([1]), isCompressed: false))
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        var second = server.createWriteFrame(opcode: .binaryFrame, payload: Data([2]), isCompressed: false)
        second.append(contentsOf: [0x82, 3, 0x11]) // Unfinished prior-generation frame.
        framer.add(data: second)
        framer.register(delegate: current)
        framer.resetForNewConnection()
        framer.add(data: server.createWriteFrame(opcode: .binaryFrame, payload: Data([9]), isCompressed: false))
        release.signal()
        wait(for: [done], timeout: 3)
        XCTAssertEqual(old.payloads, [Data([1]), Data([2])])
        XCTAssertEqual(current.payloads, [Data([9])])
    }

    func testBuiltInHTTPParsersResetIncompletePriorHandshake() {
        for parser: HTTPHandler in [FoundationHTTPHandler(), StringHTTPHandler()] {
            let recorder = HTTPRecorder()
            parser.register(delegate: recorder)
            _ = parser.parse(data: Data("HTTP/1.1 101 Switching Protocols\r\nSec-WebSocket-Accept: obsolete".utf8))
            XCTAssertTrue(recorder.headers.isEmpty)
            (parser as? ConnectionStateResetting)?.resetForNewConnection()
            _ = parser.parse(data: Data("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: current\r\n\r\n".utf8))
            XCTAssertEqual(recorder.headers.count, 1)
            XCTAssertEqual(recorder.headers.first?.first(where: { $0.key.lowercased() == "sec-websocket-accept" })?.value, "current")
        }
    }

    func testQueuedWebSocketEventsAreRejectedAfterReplacementSession() {
        let h = EngineGenerationHarness()
        let socket = Starscream.WebSocket(request: URLRequest(url: URL(string: "ws://fixture.invalid")!), engine: h.engine)
        let queue = DispatchQueue(label: "test.fearless.queued-events")
        socket.callbackQueue = queue
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        queue.async { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let done = expectation(description: "only replacement text admitted")
        socket.onEvent = { event in if case .text(let text) = event { XCTAssertEqual(text, "current"); done.fulfill() } }
        socket.connect()
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        h.framer.delegate?.frameProcessed(event: .frame(frame("old")))
        socket.forceDisconnect(); socket.connect()
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        h.framer.delegate?.frameProcessed(event: .frame(frame("current")))
        release.signal()
        wait(for: [done], timeout: 3)
    }

    func testQueuedErrorCannotSurviveReplacementSession() {
        let h = EngineGenerationHarness()
        let socket = Starscream.WebSocket(request: URLRequest(url: URL(string: "ws://fixture.invalid")!), engine: h.engine)
        let queue = DispatchQueue(label: "test.fearless.queued-error")
        socket.callbackQueue = queue
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        queue.async { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let done = expectation(description: "new session event follows dropped old error")
        socket.onEvent = { event in
            if case .error = event { XCTFail("retired error escaped generation delivery") }
            if case .text(let text) = event { XCTAssertEqual(text, "current"); done.fulfill() }
        }
        socket.connect()
        h.engine.connectionChanged(state: .failed(nil))
        socket.connect()
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        h.framer.delegate?.frameProcessed(event: .frame(frame("current")))
        release.signal()
        wait(for: [done], timeout: 3)
    }

    func testForceStopRejectsDeferredParserCallbacksBeforeFollowingStart() {
        let h = EngineGenerationHarness()
        h.start()
        let oldHTTP = h.http.delegate!, oldFrame = h.framer.delegate!
        oldHTTP.didReceiveHTTP(event: .success([:]))
        h.engine.forceStop()
        oldHTTP.didReceiveHTTP(event: .success([:]))
        oldFrame.frameProcessed(event: .frame(frame("retired")))
        XCTAssertEqual(h.events.connected, 1)
        XCTAssertTrue(h.events.text.isEmpty)
        h.start()
        XCTAssertEqual(h.transport.connects, 2)
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        XCTAssertEqual(h.events.connected, 2)
    }

    func testGracefulStopCannotBeReopenedByDeferredHandshakeWhileCloseWaits() {
        let h = EngineGenerationHarness()
        h.start()
        let oldHTTP = h.http.delegate!, oldFrame = h.framer.delegate!
        oldHTTP.didReceiveHTTP(event: .success([:]))
        h.engine.stop()
        XCTAssertEqual(h.transport.wrote.wait(timeout: .now() + 3), .success)
        oldHTTP.didReceiveHTTP(event: .success([:]))
        oldFrame.frameProcessed(event: .frame(frame("retired")))
        XCTAssertEqual(h.events.connected, 1)
        XCTAssertTrue(h.events.text.isEmpty)
        let denied = expectation(description: "stopping engine stays closed to mutation")
        h.engine.writeAuthorized(data: Data([1]), opcode: .textFrame,
            authorization: GenerationAuthority { _ in XCTFail("stopping engine reached authorization") }) { result in
                guard case .failure(let error) = result else { return XCTFail("expected denial") }
                XCTAssertEqual(error as? AuthorizedWriteError, .connectionChanged); denied.fulfill()
            }
        wait(for: [denied], timeout: 3)
        h.start()
        XCTAssertEqual(h.transport.connects, 2)
    }

    func testTerminalErrorStillDeliversBeforeReplacementStarts() {
        let h = EngineGenerationHarness()
        let socket = Starscream.WebSocket(request: URLRequest(url: URL(string: "ws://fixture.invalid")!), engine: h.engine)
        let error = expectation(description: "current failed session still notifies client")
        socket.onEvent = { event in if case .error = event { error.fulfill() } }
        socket.connect()
        h.engine.connectionChanged(state: .failed(nil))
        wait(for: [error], timeout: 3)
        XCTAssertEqual(h.transport.disconnects, 1)
    }

    func testForceStopDropsQueuedNonterminalEventsButRetainsCurrentError() {
        let h = EngineGenerationHarness()
        let socket = Starscream.WebSocket(request: URLRequest(url: URL(string: "ws://fixture.invalid")!), engine: h.engine)
        let queue = DispatchQueue(label: "test.fearless.stopped-queue")
        socket.callbackQueue = queue
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        queue.async { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let error = expectation(description: "stopped session retains terminal notification")
        socket.onEvent = { event in
            if case .error = event { error.fulfill() }
            else { XCTFail("stopped session admitted nonterminal event") }
        }
        socket.connect()
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        h.framer.delegate?.frameProcessed(event: .frame(frame("retired")))
        h.engine.connectionChanged(state: .failed(nil))
        socket.forceDisconnect()
        release.signal()
        wait(for: [error], timeout: 3)
    }

    func testOldCloseCompletionCannotDisconnectReplacement() {
        let h = EngineGenerationHarness()
        h.start(); h.http.delegate?.didReceiveHTTP(event: .success([:]))
        h.engine.stop()
        XCTAssertEqual(h.transport.wrote.wait(timeout: .now() + 3), .success)
        let completion = h.transport.completion
        h.engine.forceStop(); h.start()
        completion?(nil)
        XCTAssertEqual(h.transport.disconnects, 1)
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        XCTAssertEqual(h.events.connected, 2)
    }

    func testStartDuringQueuedCloseRejectsOldControlFrameOnReplacement() {
        let h = EngineGenerationHarness()
        h.start(); h.http.delegate?.didReceiveHTTP(event: .success([:]))
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        h.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        h.engine.stop()
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        h.start()
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        release.signal()
        XCTAssertEqual(h.transport.boundAttempted.wait(timeout: .now() + 3), .success)
        XCTAssertTrue(h.transport.boundContexts.isEmpty)
        XCTAssertEqual(h.transport.disconnects, 1)
        XCTAssertEqual(h.events.connected, 2)
    }

    func testOldCloseContextCannotWriteBytesToActualReplacementTCP() throws {
        let h = try TCPGenerationHarness(test: self)
        defer { h.close() }
        let old = try h.connect(), current = try h.connect()
        let rejected = expectation(description: "old close frame rejected outside writer lock")
        h.transport.writeConnectionBound(data: Data("old-close".utf8), context: old) { error in
            XCTAssertEqual(error as? AuthorizedWriteError, .connectionChanged)
            XCTAssertTrue(h.transport.captureEventContext() === current)
            rejected.fulfill()
        }
        let received = expectation(description: "only current bytes reach replacement")
        let bytes = Data("current-control".utf8)
        h.peer.receive(minimumIncompleteLength: bytes.count, maximumLength: bytes.count) { data, _, _, error in
            XCTAssertNil(error); XCTAssertEqual(data, bytes); received.fulfill()
        }
        h.transport.writeConnectionBound(data: bytes, context: current) { XCTAssertNil($0) }
        wait(for: [rejected, received], timeout: 3)
    }

    func testDisconnectBeforeHandshakeRetiresTransportAndAllowsFollowingStart() {
        let h = EngineGenerationHarness()
        h.start(); h.engine.stop(); h.start()
        XCTAssertEqual(h.transport.disconnects, 1)
        XCTAssertEqual(h.transport.connects, 2)
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        XCTAssertEqual(h.events.connected, 1)
    }

    func testStopAndReconnectWhileFinalAuthorityWaitsCancelsWithoutLockInversion() {
        let h = EngineGenerationHarness()
        h.start(); h.http.delegate?.didReceiveHTTP(event: .success([:]))
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let cancelled = expectation(description: "cancelled while authority waits")
        h.engine.writeAuthorized(data: Data("never-send".utf8), opcode: .textFrame,
            authorization: GenerationAuthority { handoff in
                entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success); try handoff()
            }) { result in
                guard case .failure(let error) = result else { return XCTFail("expected cancellation") }
                XCTAssertEqual(error as? AuthorizedWriteError, .cancelledBeforeHandoff); cancelled.fulfill()
            }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        let reconnected = expectation(description: "lifecycle completes")
        DispatchQueue.global().async { h.engine.stop(); h.start(); reconnected.fulfill() }
        wait(for: [cancelled], timeout: 3)
        release.signal()
        wait(for: [reconnected], timeout: 3)
        XCTAssertEqual(h.transport.boundAttempted.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(h.transport.authorizedWrites, 0)
        let current = h.transport.captureWriteContext()
        XCTAssertFalse(h.transport.boundContexts.contains { $0 === current })
        h.http.delegate?.didReceiveHTTP(event: .success([:]))
        XCTAssertEqual(h.events.connected, 2)
    }

    private func frame(_ text: String) -> Frame {
        let data = Data(text.utf8)
        return Frame(isFin: true, needsDecompression: false, isMasked: false, opcode: .textFrame,
                     payloadLength: UInt64(data.count), payload: data, closeCode: 0)
    }
}

private final class GenerationSink: TransportEventClient {
    private let lock = NSLock()
    private var events = 0, failed = 0
    private var payloads = [Data]()
    let connected = DispatchSemaphore(value: 0)
    let received = DispatchSemaphore(value: 0)
    var onRead: (() -> Void)?
    var count: Int { lock.lock(); defer { lock.unlock() }; return events }
    var failures: Int { lock.lock(); defer { lock.unlock() }; return failed }
    var data: [Data] { lock.lock(); defer { lock.unlock() }; return payloads }
    func connectionChanged(state: ConnectionState) {
        lock.lock(); events += 1
        if case .failed = state { failed += 1 }
        if case .receive(let data) = state { payloads.append(data) }
        lock.unlock()
        if case .connected = state { connected.signal() }
        if case .receive = state { onRead?(); received.signal() }
    }
}
private final class TCPGenerationHarness {
    let transport = TCPTransport(), sink = GenerationSink()
    let listener: NWListener, url: URL
    let accepted = DispatchSemaphore(value: 0)
    private let queue = DispatchQueue(label: "test.fearless.generation.peer")
    private let lock = NSLock()
    private var peers = [NWConnection]()
    private var receiveCallbacks = [(Data?, Bool, NWError?) -> Void]()
    var reads: [(Data?, Bool, NWError?) -> Void] { lock.lock(); defer { lock.unlock() }; return receiveCallbacks }
    var peer: NWConnection { lock.lock(); defer { lock.unlock() }; return peers.last! }
    init(test: XCTestCase, mockReads: Bool = true) throws {
        listener = try NWListener(using: .tcp, on: .any)
        let ready = DispatchSemaphore(value: 0)
        listener.newConnectionHandler = { $0.cancel() }
        listener.stateUpdateHandler = { if case .ready = $0 { ready.signal() } }
        listener.start(queue: queue)
        XCTAssertEqual(ready.wait(timeout: .now() + 3), .success)
        url = URL(string: "ws://127.0.0.1:\(try XCTUnwrap(listener.port).rawValue)")!
        listener.newConnectionHandler = { [weak self] peer in
            guard let self = self else { return }
            self.lock.lock(); self.peers.append(peer); self.lock.unlock()
            peer.start(queue: self.queue); self.accepted.signal()
        }
        transport.register(delegate: sink)
        if mockReads {
            transport.receiveOverride = { [weak self] _, callback in
                guard let self = self else { return }
                self.lock.lock(); self.receiveCallbacks.append(callback); self.lock.unlock()
            }
        }
    }
    func connect() throws -> TCPTransport.EventContext {
        transport.connect(url: url)
        XCTAssertEqual(sink.connected.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(accepted.wait(timeout: .now() + 3), .success)
        return try XCTUnwrap(transport.captureEventContext())
    }
    func close() {
        transport.disconnect()
        lock.lock(); let connections = peers; lock.unlock()
        for connection in connections { connection.cancel() }
        listener.cancel()
    }
}
private final class GenerationAuthority: WebSocketWriteAuthorizing {
    let action: (() throws -> Void) throws -> Void
    init(_ action: @escaping (() throws -> Void) throws -> Void) { self.action = action }
    func authorize(_ handoff: () throws -> Void) throws { try action(handoff) }
}
private final class FrameRecorder: FramerEventClient {
    var payloads = [Data]()
    var onFrame: ((Data) -> Void)?
    func frameProcessed(event: FrameEvent) {
        if case .frame(let frame) = event { payloads.append(frame.payload); onFrame?(frame.payload) }
        else { XCTFail("unexpected framing error") }
    }
}
private final class DeferredFramer: Starscream.Framer {
    var delegate: FramerEventClient?
    var beforeFrame: (() -> Void)?
    func add(data: Data) {}
    func register(delegate: FramerEventClient) { self.delegate = delegate }
    func createWriteFrame(opcode: FrameOpCode, payload: Data, isCompressed: Bool) -> Data { beforeFrame?(); return payload }
    func updateCompression(supports: Bool) {}
    func supportsCompression() -> Bool { false }
}
private final class DeferredHTTP: HTTPHandler {
    var delegate: HTTPHandlerDelegate?
    func convert(request: URLRequest) -> Data { Data() }
    func parse(data: Data) -> Int { -1 }
    func register(delegate: HTTPHandlerDelegate) { self.delegate = delegate }
}
private final class HTTPRecorder: HTTPHandlerDelegate {
    var headers = [[String: String]]()
    func didReceiveHTTP(event: HTTPEvent) {
        if case .success(let values) = event { headers.append(values) }
        else { XCTFail("fresh handshake failed after reset") }
    }
}
private final class GenerationHeaders: HeaderValidator {
    func validate(headers: [String: String], key: String) -> Error? { nil }
}
private final class EngineEvents: EngineDelegate {
    var text = [String](), connected = 0
    func didReceive(event: WebSocketEvent) {
        if case .text(let value) = event { text.append(value) }
        if case .connected = event { connected += 1 }
    }
}
private final class SerializedGenerationTransport: AuthorizedTransport, ConnectionEventSerializing, ConnectionBoundTransport {
    let wrote = DispatchSemaphore(value: 0)
    let boundAttempted = DispatchSemaphore(value: 0)
    private let eventLock = NSRecursiveLock(), contextLock = NSLock()
    private var context: NSObject? = NSObject()
    var completion: ((Error?) -> Void)?
    var disconnects = 0, authorizedWrites = 0, connects = 0
    private var controlContexts = [AnyObject]()
    var boundContexts: [AnyObject] { contextLock.lock(); defer { contextLock.unlock() }; return controlContexts }
    var usingTLS: Bool { false }
    func withConnectionEvents(_ action: () -> Void) { eventLock.lock(); defer { eventLock.unlock() }; action() }
    func register(delegate: TransportEventClient) {}
    func connect(url: URL, timeout: Double, certificatePinning: CertificatePinning?) {
        withConnectionEvents { contextLock.lock(); context = NSObject(); connects += 1; contextLock.unlock() }
    }
    func disconnect() {
        withConnectionEvents { contextLock.lock(); context = nil; disconnects += 1; contextLock.unlock() }
    }
    func write(data: Data, completion: @escaping (Error?) -> Void) { self.completion = completion; wrote.signal() }
    func captureWriteContext() -> AnyObject? { contextLock.lock(); defer { contextLock.unlock() }; return context }
    func writeConnectionBound(data: Data, context: AnyObject, completion: @escaping (Error?) -> Void) {
        contextLock.lock()
        let current = context === self.context
        if current { controlContexts.append(context); self.completion = completion }
        contextLock.unlock()
        if current { wrote.signal() } else { completion(AuthorizedWriteError.connectionChanged) }
        boundAttempted.signal()
    }
    func write(data: Data, context: AnyObject, operation: AuthorizedWrite, authorization: WebSocketWriteAuthorizing,
               completion: @escaping (Error?) -> Void) throws {
        contextLock.lock(); defer { contextLock.unlock() }
        guard context === self.context else { throw AuthorizedWriteError.connectionChanged }
        operation.perform(authorization: authorization) { authorizedWrites += 1; completion(nil) }
    }
}
private final class EngineGenerationHarness {
    let transport = SerializedGenerationTransport(), framer = DeferredFramer(), http = DeferredHTTP(), events = EngineEvents()
    let engine: WSEngine
    init() {
        engine = WSEngine(transport: transport, headerValidator: GenerationHeaders(), httpHandler: http, framer: framer)
        engine.register(delegate: events)
    }
    func start() { engine.start(request: URLRequest(url: URL(string: "ws://fixture.invalid")!)) }
}
#endif
