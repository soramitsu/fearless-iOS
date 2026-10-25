import Foundation
import XCTest
@testable import SSFUtils
import RobinHood

final class AuthorizedRPCOperationTests: XCTestCase {
    func testOperationPropagatesExactGuardAndReturnsRPCResult() throws {
        let engine = OperationEngine()
        let authority = OperationGuard()
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic", parameters: ["signed-fixture"],
            requestOptions: JSONRPCOptions(writeAuthorization: authority))
        operation.main()
        XCTAssertEqual(try XCTUnwrap(operation.result).get(), "ok")
        XCTAssertTrue(engine.options?.writeAuthorization === operation.requestOptions.writeAuthorization)
        XCTAssertEqual(authority.calls, 1)
        XCTAssertEqual(engine.options?.resendOnReconnect, false)
        XCTAssertTrue(engine.cancelled.isEmpty)
    }

    func testGuardedTimeoutCancelsWriterAndRequiresUnknownOutcomeReconciliation() {
        let engine = OperationEngine()
        engine.respondImmediately = false
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic", timeout: 0,
            requestOptions: JSONRPCOptions(writeAuthorization: OperationGuard()))
        operation.main()
        XCTAssertEqual(engine.cancelled, [77])
        guard case .failure(let error) = operation.result else { return XCTFail("expected timeout") }
        XCTAssertEqual(error as? JSONRPCEngineError, .submissionOutcomeUnknown)
    }

    func testCancellationBeforeStartNeverQueuesRequest() {
        let engine = OperationEngine()
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic",
            requestOptions: JSONRPCOptions(writeAuthorization: OperationGuard()))
        operation.cancel()
        operation.main()
        XCTAssertNil(engine.options)
        assertError(operation.result, .requestNotSent)
        XCTAssertTrue(engine.cancelled.isEmpty)
    }

    func testCancellationDuringRequestIDPublicationCancelsReturnedID() {
        let engine = OperationEngine()
        engine.respondImmediately = false
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        engine.onCall = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic", timeout: 60,
            requestOptions: JSONRPCOptions(writeAuthorization: OperationGuard()))
        let done = expectation(description: "cancelled operation finishes")
        DispatchQueue.global().async { operation.main(); done.fulfill() }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        operation.cancel()
        release.signal()
        wait(for: [done], timeout: 3)
        XCTAssertEqual(engine.cancelled, [77])
        assertError(operation.result, .requestNotSent)
    }

    func testLegacyOperationKeepsItsOriginalOptionsAndTimeoutError() {
        let engine = OperationEngine()
        engine.respondImmediately = false
        let operation = JSONRPCListOperation<String>(engine: engine, method: "system_health", timeout: 0)
        operation.main()
        XCTAssertEqual(engine.options?.resendOnReconnect, true)
        XCTAssertNil(engine.options?.writeAuthorization)
        XCTAssertTrue(engine.cancelled.isEmpty)
        guard case .failure(let error) = operation.result else { return XCTFail("expected timeout") }
        XCTAssertEqual(error as? JSONRPCOperationError, .timeout)
    }

    func testCancellationBeforePublishedIDPreventsActualWriterHandoff() {
        let harness = NetworkHarness()
        let engine = PublishingEngine(harness.rpc)
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        let authority = OperationGuard()
        authority.beforeHandoff = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic", parameters: ["signed-fixture"],
            requestOptions: JSONRPCOptions(writeAuthorization: authority))
        let done = expectation(description: "cancelled before ID")
        DispatchQueue.global().async { operation.main(); done.fulfill() }
        XCTAssertEqual(engine.queued.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        XCTAssertNil(operation.requestId)
        operation.cancel()
        release.signal()
        engine.publish.signal()
        wait(for: [done], timeout: 3)
        harness.drain()
        XCTAssertEqual(harness.transport.sent.count, 0)
        assertError(operation.result, .requestNotSent)
    }

    func testCancellationAfterHandoffBeforePublishedIDRetainsUnknownOutcome() {
        let harness = NetworkHarness()
        let engine = PublishingEngine(harness.rpc)
        let sent = DispatchSemaphore(value: 0)
        harness.transport.onSend = { sent.signal() }
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic", parameters: ["signed-fixture"],
            requestOptions: JSONRPCOptions(writeAuthorization: OperationGuard()))
        let done = expectation(description: "accepted before ID")
        DispatchQueue.global().async { operation.main(); done.fulfill() }
        XCTAssertEqual(engine.queued.wait(timeout: .now() + 3), .success)
        XCTAssertEqual(sent.wait(timeout: .now() + 3), .success)
        XCTAssertNil(operation.requestId)
        operation.cancel()
        engine.publish.signal()
        wait(for: [done], timeout: 3)
        XCTAssertEqual(harness.transport.sent.count, 1)
        assertError(operation.result, .submissionOutcomeUnknown)
    }

    func testTimeoutBeforeWriterHandoffPreventsLateSubmission() {
        let harness = NetworkHarness()
        let entered = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
        harness.framer.beforeFrame = { entered.signal(); XCTAssertEqual(release.wait(timeout: .now() + 3), .success) }
        let operation = JSONRPCListOperation<String>(engine: harness.rpc, method: "author_submitExtrinsic", parameters: ["signed-fixture"], timeout: 1,
            requestOptions: JSONRPCOptions(writeAuthorization: OperationGuard()))
        let done = expectation(description: "queued request expires")
        DispatchQueue.global().async { operation.main(); done.fulfill() }
        XCTAssertEqual(entered.wait(timeout: .now() + 3), .success)
        wait(for: [done], timeout: 3)
        release.signal()
        harness.drain()
        XCTAssertEqual(harness.transport.sent.count, 0)
        assertError(operation.result, .requestNotSent)
    }

    func testCancelAfterSuccessfulResponseDoesNotReplaceTerminalReceipt() throws {
        let engine = OperationEngine()
        let operation = JSONRPCListOperation<String>(engine: engine, method: "author_submitExtrinsic",
            requestOptions: JSONRPCOptions(writeAuthorization: OperationGuard()))
        operation.main()
        operation.cancel()
        XCTAssertEqual(try XCTUnwrap(operation.result).get(), "ok")
        XCTAssertTrue(engine.cancelled.isEmpty)
    }

    private func assertError(_ result: Result<String, Error>?, _ expected: JSONRPCEngineError, file: StaticString = #file, line: UInt = #line) {
        guard case .failure(let error) = result else { return XCTFail("Expected a typed cancellation result", file: file, line: line) }
        XCTAssertEqual(error as? JSONRPCEngineError, expected, file: file, line: line)
    }
}

private final class OperationGuard: JSONRPCWriteAuthorizing {
    var beforeHandoff: (() -> Void)?
    private(set) var calls = 0
    func authorize(_ handoff: () throws -> Void) throws { calls += 1; beforeHandoff?(); try handoff() }
}
private final class OperationEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }
    var respondImmediately = true
    var onCall: (() -> Void)?
    private(set) var options: JSONRPCOptions?
    private let lock = NSLock()
    private var cancelledIDs = [UInt16]()
    var cancelled: [UInt16] { lock.lock(); defer { lock.unlock() }; return cancelledIDs }
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        self.options = options
        onCall?()
        do { try options.writeAuthorization?.authorize {} }
        catch { closure?(.failure(error)); return 77 }
        if respondImmediately { closure?(.success(try JSONDecoder().decode(T.self, from: Data("\"ok\"".utf8)))) }
        return 77
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 { 77 }
    func cancelForIdentifier(_ identifier: UInt16) { lock.lock(); cancelledIDs.append(identifier); lock.unlock() }
    func cancelForIdentifier(_ identifier: UInt16, writeAuthorization: JSONRPCWriteAuthorizing) {
        guard options?.writeAuthorization === writeAuthorization else { return }
        cancelForIdentifier(identifier)
    }
    func generateRequestId() -> UInt16 { 77 }
    func addSubscription(_ subscription: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}

/// A real SDK engine whose synchronous ID return is deliberately delayed while
/// its real Starscream writer runs. No mock writer can establish this race.
private final class PublishingEngine: JSONRPCEngine {
    let underlying: WebSocketEngine
    let queued = DispatchSemaphore(value: 0), publish = DispatchSemaphore(value: 0)
    init(_ underlying: WebSocketEngine) { self.underlying = underlying }
    var connectionName: String? { get { underlying.connectionName } set { underlying.connectionName = newValue } }
    var url: URL? { get { underlying.url } set { underlying.url = newValue } }
    var pendingEngineRequests: [JSONRPCRequest] { underlying.pendingEngineRequests }
    func callMethod<P: Codable, T: Decodable>(_ method: String, params: P?, options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        let id = try underlying.callMethod(method, params: params, options: options, completion: closure)
        queued.signal()
        XCTAssertEqual(publish.wait(timeout: .now() + 3), .success)
        return id
    }
    func subscribe<P: Codable, T: Decodable>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 {
        try underlying.subscribe(method, params: params, updateClosure: updateClosure, failureClosure: failureClosure)
    }
    func cancelForIdentifier(_ identifier: UInt16) { underlying.cancelForIdentifier(identifier) }
    func cancelForIdentifier(_ identifier: UInt16, writeAuthorization: JSONRPCWriteAuthorizing) {
        underlying.cancelForIdentifier(identifier, writeAuthorization: writeAuthorization)
    }
    func generateRequestId() -> UInt16 { underlying.generateRequestId() }
    func addSubscription(_ subscription: JSONRPCSubscribing) { underlying.addSubscription(subscription) }
    func connectIfNeeded() { underlying.connectIfNeeded() }
    func disconnectIfNeeded() { underlying.disconnectIfNeeded() }
    func unsubsribe(_ identifier: UInt16) throws { try underlying.unsubsribe(identifier) }
}
