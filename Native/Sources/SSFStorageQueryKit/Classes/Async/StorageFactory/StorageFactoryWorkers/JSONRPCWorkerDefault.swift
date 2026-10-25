import Foundation
import SSFUtils

class JSONRPCWorker<P: Codable, T: Decodable> {
    private let engine: JSONRPCEngine
    private let method: String
    private let parameters: P
    private let timeout: TimeInterval

    private var currentTask: Task<Void, Error>?

    init(
        engine: JSONRPCEngine,
        method: String,
        parameters: P,
        timeout: TimeInterval = 10
    ) {
        self.engine = engine
        self.method = method
        self.parameters = parameters
        self.timeout = timeout
    }

    /// Resumes with the response or, after `timeout`, with `JSONRPCWorkerContinuationError`,
    /// whichever comes first, and exactly once. A request that times out is cancelled in the
    /// engine.
    func performCall() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            let call = PendingRPCCall(continuation)

            currentTask = Task {
                let timeoutTask = Task {
                    let duration = UInt64(timeout * 1_000_000_000)
                    try await Task.sleep(nanoseconds: duration)

                    let outcome = call.finish(with: .failure(JSONRPCWorkerContinuationError()))
                    if outcome.didResume, let requestId = outcome.requestId {
                        engine.cancelForIdentifier(requestId)
                    }
                }

                do {
                    let requestId = try engine.callMethod(
                        method,
                        params: parameters
                    ) { (result: Result<T, Error>) in
                        timeoutTask.cancel()
                        call.finish(with: result)
                    }

                    if !call.track(requestId: requestId) {
                        // The call timed out before the engine handed back its id.
                        engine.cancelForIdentifier(requestId)
                    }
                } catch {
                    timeoutTask.cancel()
                    call.finish(with: .failure(error))
                }
            }
        }
    }

    func cancel() {
        currentTask?.cancel()
    }
}

public struct JSONRPCWorkerContinuationError: LocalizedError {
    public var errorDescription: String? = "timeout"
}

/// The response and the timeout race to finish a call; whichever comes second must not resume
/// the continuation again.
private final class PendingRPCCall<T> {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, Error>?
    private var requestId: UInt16?

    init(_ continuation: CheckedContinuation<T, Error>) {
        self.continuation = continuation
    }

    /// Records the engine's id for the request. Returns false when the call already finished.
    func track(requestId: UInt16) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard continuation != nil else {
            return false
        }

        self.requestId = requestId
        return true
    }

    @discardableResult
    func finish(with result: Result<T, Error>) -> (didResume: Bool, requestId: UInt16?) {
        lock.lock()
        let pending = continuation
        let requestId = self.requestId
        continuation = nil
        lock.unlock()

        guard let pending else {
            return (false, requestId)
        }

        pending.resume(with: result)
        return (true, requestId)
    }
}
