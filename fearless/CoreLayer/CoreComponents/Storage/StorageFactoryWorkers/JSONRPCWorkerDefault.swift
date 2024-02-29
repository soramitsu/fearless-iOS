import Foundation
import SSFUtils

class JSONRPCWorker<P: Encodable, T: Decodable> {
    private let engine: JSONRPCEngine
    private let method: String
    private let parameters: P
    private let timeout: TimeInterval

    private var requestId: UInt16?
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

    func performCall() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            currentTask = Task {
                let timeoutTask = Task {
                    let duration = UInt64(timeout * 1_000_000_000)
                    try await Task.sleep(nanoseconds: duration)
                    continuation.resume(throwing: JSONRPCWorkerContinuationError())
                }

                do {
                    requestId = try engine.callMethod(
                        method,
                        params: parameters
                    ) { (result: Result<T, Error>) in
                        timeoutTask.cancel()
                        continuation.resume(with: result)
                    }
                } catch {
                    continuation.resume(throwing: error)
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
