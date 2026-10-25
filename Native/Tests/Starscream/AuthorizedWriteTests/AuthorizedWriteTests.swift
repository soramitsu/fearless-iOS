import Foundation
import XCTest
@testable import Starscream

final class AuthorizedWriteTests: XCTestCase {
    private let bytes = Data("immutable-transaction".utf8)

    func testDeniedAuthorityNeverHandsOff() {
        let done = expectation(description: "denied")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            XCTAssertEqual(result.error as? TestError, .denied); done.fulfill()
        }
        var writes = 0
        operation.perform(authorization: Authority { _ in throw TestError.denied }) { writes += 1 }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(writes, 0)
    }

    func testCancelBeforeHandoffPreventsAuthorityAndWrite() {
        let done = expectation(description: "cancel")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .cancelledBeforeHandoff); done.fulfill()
        }
        XCTAssertEqual(operation.cancel(), .notHandedOff)
        operation.perform(authorization: Authority { _ in XCTFail("authority invoked") }) { XCTFail("write") }
        operation.cancel()
        wait(for: [done], timeout: 3)
    }

    func testCancelAfterHandoffIsUnknownAndNeverResubmits() {
        let done = expectation(description: "unknown")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .outcomeUnknown); done.fulfill()
        }
        var writes = 0
        operation.perform(authorization: Authority()) { writes += 1 }
        XCTAssertEqual(operation.cancel(), .mayHaveBeenHandedOff)
        operation.complete(.success(()))
        XCTAssertEqual(operation.cancel(), .mayHaveBeenHandedOff)
        operation.perform(authorization: Authority()) { writes += 1 }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(writes, 1)
    }

    func testTransportFailureAfterAcceptanceHasUnknownOutcome() {
        let done = expectation(description: "unknown")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .outcomeUnknown); done.fulfill()
        }
        operation.perform(authorization: Authority()) {}
        operation.complete(.failure(TestError.transport))
        wait(for: [done], timeout: 3)
    }

    func testThrowBeforeTransportAcceptancePreservesKnownFailure() {
        let done = expectation(description: "known failure")
        let operation = AuthorizedWrite(callbackQueue: .global()) { result in
            XCTAssertEqual(result.error as? TestError, .transport); done.fulfill()
        }
        operation.perform(authorization: Authority()) { throw TestError.transport }
        wait(for: [done], timeout: 3)
    }

    func testMissingAndDuplicateHandoffsFailWithoutDuplicateBytes() {
        for duplicate in [false, true] {
            let done = expectation(description: "invalid authority")
            let operation = AuthorizedWrite(callbackQueue: .global()) { result in
                XCTAssertEqual(result.error as? AuthorizedWriteError,
                               duplicate ? .outcomeUnknown : .authorizationDidNotHandoff)
                done.fulfill()
            }
            var writes = 0
            operation.perform(authorization: Authority { handoff in
                if duplicate { try handoff(); try handoff() }
            }) { writes += 1 }
            wait(for: [done], timeout: 3)
            XCTAssertEqual(writes, duplicate ? 1 : 0)
        }
    }

    func testCallbackCanReenterCancellationOutsideLocks() {
        let done = expectation(description: "reentrant callback")
        var operation: AuthorizedWrite!
        operation = AuthorizedWrite(callbackQueue: .global()) { _ in operation.cancel(); done.fulfill() }
        operation.perform(authorization: Authority()) {}
        operation.complete(.success(()))
        wait(for: [done], timeout: 3)
    }

    func testFramePreparationPrecedesFinalAuthorization() {
        let harness = Harness()
        var valid = true
        harness.framer.beforeFrame = { valid = false }
        let done = expectation(description: "expired during preparation")
        harness.write(bytes, authority: Authority { handoff in
            guard valid else { throw TestError.denied }; try handoff()
        }) { result in XCTAssertEqual(result.error as? TestError, .denied); done.fulfill() }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(harness.transport.writes.count, 0)
    }

    func testQueuedCancellationPreventsBytesAndCompletesOnce() {
        let harness = Harness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        harness.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let done = expectation(description: "cancel")
        let operation = harness.write(bytes) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .cancelledBeforeHandoff); done.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        operation.cancel()
        release.signal()
        wait(for: [done], timeout: 3)
        harness.drain()
        XCTAssertTrue(harness.transport.writes.isEmpty)
    }

    func testDisconnectDuringPreparationRejectsOldAndNewWrites() {
        let harness = Harness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        harness.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let old = expectation(description: "old connection")
        harness.write(bytes) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .cancelledBeforeHandoff); old.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        harness.engine.forceStop()
        let new = expectation(description: "after disconnect")
        harness.write(bytes) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .connectionChanged); new.fulfill()
        }
        release.signal()
        wait(for: [old, new], timeout: 3)
        XCTAssertTrue(harness.transport.writes.isEmpty)
    }

    func testReconnectedEngineNeverReplaysOldGeneration() {
        let harness = Harness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        harness.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let done = expectation(description: "old epoch")
        harness.write(bytes) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .cancelledBeforeHandoff); done.fulfill()
        }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        harness.engine.connectionChanged(state: .waiting(error: TestError.transport))
        harness.transport.context = NSObject()
        harness.engine.didReceiveHTTP(event: .success([:]))
        release.signal()
        wait(for: [done], timeout: 3)
        XCTAssertTrue(harness.transport.writes.isEmpty)
    }

    func testStopCancelsDequeuedWriteWhileItWaitsForAuthority() {
        let harness = Harness()
        let waiting = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let cancelled = expectation(description: "cancelled while authority waits")
        harness.write(bytes, authority: Authority { handoff in
            waiting.signal()
            XCTAssertEqual(release.wait(timeout: .now() + 3), .success)
            try handoff()
        }) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .cancelledBeforeHandoff)
            cancelled.fulfill()
        }
        XCTAssertEqual(waiting.wait(timeout: .now() + 3), .success)
        let stopped = expectation(description: "stop completed")
        DispatchQueue.global().async { harness.engine.forceStop(); stopped.fulfill() }
        wait(for: [cancelled], timeout: 3)
        release.signal()
        wait(for: [stopped], timeout: 3)
        XCTAssertTrue(harness.transport.writes.isEmpty)
    }

    func testFinalAuthorizationFollowsTransportLockWait() {
        let harness = Harness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        var valid = true
        harness.transport.beforeLock = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let done = expectation(description: "lock delay")
        harness.write(bytes, authority: Authority { handoff in
            guard valid else { throw TestError.denied }; try handoff()
        }) { result in XCTAssertEqual(result.error as? TestError, .denied); done.fulfill() }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        valid = false
        release.signal()
        wait(for: [done], timeout: 3)
        XCTAssertTrue(harness.transport.writes.isEmpty)
    }

    func testInlineTransportCallbackCanReenterEngineWithoutDeadlock() {
        let harness = Harness()
        let done = expectation(description: "reentrant engine")
        harness.write(bytes) { result in
            XCTAssertNil(result.error)
            harness.engine.forceStop()
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(harness.transport.writes, [bytes])
    }

    func testDisconnectedAndUnqualifiedTransportFailClosed() {
        let disconnected = WSEngine(transport: FakeTransport())
        let unsupported = WSEngine(transport: LegacyTransport())
        for (engine, expected) in [(disconnected, AuthorizedWriteError.connectionChanged), (unsupported, .unsupportedTransport)] {
            let done = expectation(description: "unsupported")
            engine.writeAuthorized(data: bytes, opcode: .textFrame, authorization: Authority()) { result in
                XCTAssertEqual(result.error as? AuthorizedWriteError, expected); done.fulfill()
            }
            wait(for: [done], timeout: 3)
        }
    }

    func testCompressionFailsClosedBeforeStatefulPreparation() {
        let compression = Compression()
        let engine = WSEngine(transport: FakeTransport(), compressionHandler: compression)
        let done = expectation(description: "compression")
        engine.writeAuthorized(data: bytes, opcode: .textFrame, authorization: Authority()) { result in
            XCTAssertEqual(result.error as? AuthorizedWriteError, .unsupportedCompression); done.fulfill()
        }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(compression.calls, 0)
    }

    func testLegacyWriteContinuesWithoutAuthorization() {
        let harness = Harness()
        let done = expectation(description: "legacy")
        harness.engine.write(data: bytes, opcode: .textFrame) { done.fulfill() }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(harness.transport.legacyWrites, [bytes])
    }
}

private enum TestError: Error { case denied, transport }
private extension Result where Success == Void, Failure == Error {
    var error: Error? { if case .failure(let error) = self { return error }; return nil }
}
private final class Authority: WebSocketWriteAuthorizing {
    let action: (() throws -> Void) throws -> Void
    init(_ action: @escaping (() throws -> Void) throws -> Void = { try $0() }) { self.action = action }
    func authorize(_ handoff: () throws -> Void) throws { try action(handoff) }
}
private final class HeaderChecker: HeaderValidator {
    func validate(headers: [String: String], key: String) -> Error? { nil }
}
private final class TestFramer: Framer {
    var beforeFrame: (() -> Void)?
    func add(data: Data) {}
    func register(delegate: FramerEventClient) {}
    func createWriteFrame(opcode: FrameOpCode, payload: Data, isCompressed: Bool) -> Data { beforeFrame?(); return payload }
    func updateCompression(supports: Bool) {}
    func supportsCompression() -> Bool { false }
}
private class LegacyTransport: Transport {
    var usingTLS: Bool { false }
    var legacyWrites = [Data]()
    func register(delegate: TransportEventClient) {}
    func connect(url: URL, timeout: Double, certificatePinning: CertificatePinning?) {}
    func disconnect() {}
    func write(data: Data, completion: @escaping (Error?) -> Void) { legacyWrites.append(data); completion(nil) }
}
private final class FakeTransport: LegacyTransport, AuthorizedTransport {
    var context: NSObject? = NSObject()
    var writes = [Data]()
    var beforeLock: (() -> Void)?
    private let lock = NSLock()
    func captureWriteContext() -> AnyObject? { context }
    override func disconnect() { context = nil }
    func write(data: Data, context: AnyObject, operation: AuthorizedWrite,
               authorization: WebSocketWriteAuthorizing, completion: @escaping (Error?) -> Void) throws {
        beforeLock?()
        lock.lock(); defer { lock.unlock() }
        guard context === self.context else { throw AuthorizedWriteError.connectionChanged }
        operation.perform(authorization: authorization) { writes.append(data); completion(nil) }
    }
}
private final class Compression: CompressionHandler {
    var calls = 0
    func load(headers: [String: String]) {}
    func decompress(data: Data, isFinal: Bool) -> Data? { nil }
    func compress(data: Data) -> Data? { calls += 1; return data }
}
private final class Harness {
    let transport = FakeTransport()
    let framer = TestFramer()
    let engine: WSEngine
    init() {
        engine = WSEngine(transport: transport, headerValidator: HeaderChecker(), framer: framer)
        engine.start(request: URLRequest(url: URL(string: "wss://example.invalid")!))
        engine.didReceiveHTTP(event: .success([:]))
    }
    @discardableResult
    func write(_ data: Data, authority: WebSocketWriteAuthorizing = Authority(), completion: @escaping (Result<Void, Error>) -> Void) -> AuthorizedWrite {
        engine.writeAuthorized(data: data, opcode: .textFrame, authorization: authority, completion: completion)
    }
    func drain() {
        framer.beforeFrame = nil
        let done = DispatchSemaphore(value: 0)
        engine.write(data: Data(), opcode: .textFrame) { done.signal() }
        XCTAssertEqual(done.wait(timeout: .now() + 3), .success)
    }
}
