import Foundation
import RobinHood

enum JSONRPCOperationError: Error {
    case timeout
}

/// Cancellation is independent of request-ID publication. The final check is
/// inside the application's fresh-authority scope and never waits for a lock.
private final class OperationWriteAuthorization: JSONRPCWriteAuthorizing {
    private let lock = NSLock()
    private let applicationAuthorization: JSONRPCWriteAuthorizing
    private var cancelled = false
    private var handoffAttempted = false

    init(_ applicationAuthorization: JSONRPCWriteAuthorizing) {
        self.applicationAuthorization = applicationAuthorization
    }

    func authorize(_ handoff: () throws -> Void) throws {
        lock.lock()
        let denied = cancelled || handoffAttempted
        lock.unlock()
        guard !denied else { throw JSONRPCEngineError.requestNotSent }
        try applicationAuthorization.authorize {
            guard lock.try() else { throw JSONRPCEngineError.requestNotSent }
            defer { lock.unlock() }
            guard !cancelled, !handoffAttempted else { throw JSONRPCEngineError.requestNotSent }
            // Once entered, an error can no longer prove non-submission. Keep
            // the uncertainty even when cancellation precedes ID publication.
            handoffAttempted = true
            try handoff()
        }
    }

    func cancel() -> JSONRPCEngineError {
        lock.lock()
        defer { lock.unlock() }
        cancelled = true
        return handoffAttempted ? .submissionOutcomeUnknown : .requestNotSent
    }
}

public class JSONRPCOperation<P: Codable, T: Decodable>: BaseOperation<T> {
    public let engine: JSONRPCEngine
    private let requestLock = NSLock()
    private var currentRequestId: UInt16?
    private(set) var requestId: UInt16? {
        get { requestLock.lock(); defer { requestLock.unlock() }; return currentRequestId }
        set { requestLock.lock(); currentRequestId = newValue; requestLock.unlock() }
    }
    public let requestOptions: JSONRPCOptions
    private let writeAuthorization: OperationWriteAuthorization?
    private let completionSignal = DispatchSemaphore(value: 0)
    private let resultLock = NSLock()
    private var storedResult: Result<T, Error>?
    override public var result: Result<T, Error>? {
        get { resultLock.lock(); defer { resultLock.unlock() }; return storedResult }
        set { resultLock.lock(); storedResult = newValue; resultLock.unlock() }
    }
    public let method: String
    public var parameters: P?
    public let timeout: Int

    public init(engine: JSONRPCEngine, method: String, parameters: P? = nil, timeout: Int = 10,
                requestOptions: JSONRPCOptions = JSONRPCOptions()) {
        self.engine = engine
        self.method = method
        self.parameters = parameters
        self.timeout = timeout
        let authorization = requestOptions.writeAuthorization.map(OperationWriteAuthorization.init)
        writeAuthorization = authorization
        self.requestOptions = authorization.map { JSONRPCOptions(writeAuthorization: $0) } ?? requestOptions

        super.init()
    }

    override public func main() {
        defer { requestId = nil }
        super.main()

        if isCancelled {
            return
        }

        if result != nil {
            return
        }

        do {
            requestId = try engine.callMethod(method, params: parameters, options: requestOptions) { [weak self] (result: Result<T, Error>) in
                guard let self = self else { return }
                if self.writeAuthorization == nil, self.isCancelled {
                    self.completionSignal.signal()
                    return
                }
                if case .failure(let error) = result, error as? JSONRPCEngineError == .clientCancelled {
                    if let authorization = self.writeAuthorization {
                        self.finish(.failure(authorization.cancel()))
                    }
                } else {
                    self.finish(result)
                }
                self.completionSignal.signal()
            }

            // Cancellation may race with the synchronous request enqueue.
            // Publish the ID first, then cancel again if that race occurred.
            if isCancelled, let identifier = requestId {
                cancelRequest(identifier)
                return
            }

            let status = completionSignal.wait(timeout: .now() + .seconds(timeout))

            if status == .timedOut {
                if let authorization = writeAuthorization {
                    finish(.failure(authorization.cancel()))
                    if let identifier = requestId { cancelRequest(identifier) }
                } else {
                    finish(.failure(JSONRPCOperationError.timeout))
                }
                return
            }

        } catch {
            finish(.failure(error))
        }
    }

    override public func cancel() {
        if let authorization = writeAuthorization {
            finish(.failure(authorization.cancel()))
            completionSignal.signal()
        }
        super.cancel()
        if let requestId = requestId {
            cancelRequest(requestId)
        }
    }

    private func cancelRequest(_ identifier: UInt16) {
        if let authorization = writeAuthorization {
            engine.cancelForIdentifier(identifier, writeAuthorization: authorization)
        } else {
            engine.cancelForIdentifier(identifier)
        }
    }

    private func finish(_ value: Result<T, Error>) {
        resultLock.lock()
        if storedResult == nil { storedResult = value }
        resultLock.unlock()
    }
}

public final class JSONRPCListOperation<T: Decodable>: JSONRPCOperation<[String], T> {}

public extension JSONRPCOperation {
    static func failureOperation(_ error: Error) -> JSONRPCOperation<P, T> {
        let mockEngine = WebSocketEngine(
            connectionName: nil,
            url: URL(string: "https://wiki.fearlesswallet.io")!,
            autoconnect: false
        )
        let operation = JSONRPCOperation<P, T>(engine: mockEngine, method: "")
        operation.result = .failure(error)
        return operation
    }
}
