import MocksBasket
import SSFUtils
import XCTest

@testable import SSFStorageQueryKit

final class JSONRPCWorkerTests: XCTestCase {
    func testTimeout() async throws {
        let connection = JSONRPCEngineMock()
        let worker = JSONRPCWorker<String, String>(
            engine: connection,
            method: "timeout",
            parameters: "params",
            timeout: TimeInterval(0.1)
        )

        do {
            let _: String = try await worker.performCall()
            XCTFail("method should to throw timeout error")
        } catch {
            XCTAssertTrue(error is JSONRPCWorkerContinuationError)
        }
    }

    func testResult() async throws {
        let connection = JSONRPCEngineMock()
        connection.completionResult = "success"
        let worker = JSONRPCWorker<String, String>(
            engine: connection,
            method: "timeout",
            parameters: "params",
            timeout: TimeInterval(0.1)
        )

        let success: String = try await worker.performCall()
        XCTAssertEqual(success, "success")
    }

    func testATimedOutRequestIsCancelledInTheEngine() async throws {
        let engine = DeferredResponseEngine()
        let worker = JSONRPCWorker<String, String>(
            engine: engine,
            method: "slow",
            parameters: "params",
            timeout: TimeInterval(0.1)
        )

        do {
            let _: String = try await worker.performCall()
            XCTFail("The call should time out")
        } catch {
            XCTAssertTrue(error is JSONRPCWorkerContinuationError)
        }

        XCTAssertEqual(engine.cancelledIds, [DeferredResponseEngine.requestId])
    }

    func testAResponseAfterTheTimeoutDoesNotResumeTheCallerAgain() async throws {
        let engine = DeferredResponseEngine()
        let worker = JSONRPCWorker<String, String>(
            engine: engine,
            method: "slow",
            parameters: "params",
            timeout: TimeInterval(0.1)
        )

        do {
            let _: String = try await worker.performCall()
            XCTFail("The call should time out")
        } catch {
            XCTAssertTrue(error is JSONRPCWorkerContinuationError)
        }

        // A second resume of the checked continuation would trap here.
        engine.respond("late")
        engine.respond("later")
    }

    func testAnEngineErrorIsReportedAsIs() async throws {
        let engine = DeferredResponseEngine()
        engine.callError = JSONRPCEngineError.requestNotSent
        let worker = JSONRPCWorker<String, String>(
            engine: engine,
            method: "failing",
            parameters: "params",
            timeout: TimeInterval(5)
        )

        do {
            let _: String = try await worker.performCall()
            XCTFail("The engine error should be thrown")
        } catch {
            XCTAssertEqual(error as? JSONRPCEngineError, .requestNotSent)
        }
    }
}

/// Keeps the completion of every call so a test can answer it later, like a slow node.
private final class DeferredResponseEngine: JSONRPCEngine {
    static let requestId: UInt16 = 42

    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] = []
    var callError: Error?

    private let lock = NSLock()
    private var completions: [(String) -> Void] = []
    private var cancelled: [UInt16] = []

    var cancelledIds: [UInt16] {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func callMethod<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        if let callError {
            throw callError
        }

        lock.lock()
        completions.append { value in
            if let result = value as? T {
                closure?(.success(result))
            }
        }
        lock.unlock()
        return Self.requestId
    }

    func respond(_ value: String) {
        lock.lock()
        let pending = completions
        lock.unlock()
        pending.forEach { $0(value) }
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        0
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        lock.lock()
        cancelled.append(identifier)
        lock.unlock()
    }

    func generateRequestId() -> UInt16 { Self.requestId }
    func addSubscription(_: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}
