import Foundation

public enum JSONRPCEngineError: Error {
    case emptyResult
    case remoteCancelled
    case clientCancelled
    case unknownError
    case timeout
    case requestNotSent
    case submissionOutcomeUnknown
}

public protocol JSONRPCResponseHandling {
    func handle(data: Data)
    func handle(error: Error)
}

public struct JSONRPCRequest: Equatable {
    public let requestId: UInt16
    public let data: Data
    public let options: JSONRPCOptions
    public let responseHandler: JSONRPCResponseHandling?

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.requestId == rhs.requestId }
}

struct JSONRPCResponseHandler<T: Decodable>: JSONRPCResponseHandling {
    public let completionClosure: (Result<T, Error>) -> Void

    public func handle(data: Data) {
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(JSONRPCData<T>.self, from: data)

            completionClosure(.success(response.result))

        } catch {
            completionClosure(.failure(error))
        }
    }

    public func handle(error: Error) {
        completionClosure(.failure(error))
    }
}

/// Application-owned final authorization. Called after SDK framing and blocking
/// writer lock waits. Synchronously invoke handoff once while holding fresh
/// authority; never reenter this engine, await, or retain the nonescaping action.
public protocol JSONRPCWriteAuthorizing: AnyObject {
    func authorize(_ handoff: () throws -> Void) throws
}

public struct JSONRPCOptions {
    public let resendOnReconnect: Bool
    public let writeAuthorization: JSONRPCWriteAuthorizing?

    public init(resendOnReconnect: Bool = true) {
        self.resendOnReconnect = resendOnReconnect
        writeAuthorization = nil
    }

    /// Guarded mutations can never opt into reconnection replay.
    public init(writeAuthorization: JSONRPCWriteAuthorizing) {
        resendOnReconnect = false
        self.writeAuthorization = writeAuthorization
    }
}

public protocol JSONRPCSubscribing: AnyObject {
    var requestId: UInt16 { get }
    var requestData: Data { get }
    var requestOptions: JSONRPCOptions { get }
    var remoteId: String? { get set }

    func handle(data: Data) throws
    func handle(error: Error, unsubscribed: Bool)
}

public final class JSONRPCSubscription<T: Decodable>: JSONRPCSubscribing {
    public let requestId: UInt16
    public let requestData: Data
    public let requestOptions: JSONRPCOptions
    public var remoteId: String?

    private lazy var jsonDecoder = JSONDecoder()

    public let updateClosure: (T) -> Void
    public let failureClosure: (Error, Bool) -> Void

    public init(
        requestId: UInt16,
        requestData: Data,
        requestOptions: JSONRPCOptions,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) {
        self.requestId = requestId
        self.requestData = requestData
        self.requestOptions = requestOptions
        self.updateClosure = updateClosure
        self.failureClosure = failureClosure
    }

    public func handle(data: Data) throws {
        let entity = try jsonDecoder.decode(T.self, from: data)
        updateClosure(entity)
    }

    public func handle(error: Error, unsubscribed: Bool) {
        failureClosure(error, unsubscribed)
    }
}

public protocol JSONRPCEngine: AnyObject {
    var connectionName: String? { get set }
    var url: URL? { get set }
    var pendingEngineRequests: [JSONRPCRequest] { get }

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16

    func subscribe<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    )
        throws -> UInt16

    func cancelForIdentifier(_ identifier: UInt16)

    /// Cancel only this authorization's request, even if a UInt16 ID has been
    /// reused. Engines without identity-aware removal still cannot send after
    /// the operation-owned final authorizer has been cancelled.
    func cancelForIdentifier(_ identifier: UInt16, writeAuthorization: JSONRPCWriteAuthorizing)

    func generateRequestId() -> UInt16
    func addSubscription(_ subscription: JSONRPCSubscribing)
    func reconnect(url: URL)

    func connectIfNeeded()
    func disconnectIfNeeded()
    func unsubsribe(_ identifier: UInt16) throws
}

public extension JSONRPCEngine {
    func cancelForIdentifier(_ identifier: UInt16, writeAuthorization: JSONRPCWriteAuthorizing) {}

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        try callMethod(
            method,
            params: params,
            options: JSONRPCOptions(),
            completion: closure
        )
    }

    func reconnect(url _: URL) {}
}
