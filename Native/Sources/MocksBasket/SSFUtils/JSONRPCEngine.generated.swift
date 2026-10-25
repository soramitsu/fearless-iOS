import UIKit
@testable import SSFUtils

public enum JSONRPCEngineMockError: Error {
    case typesDoNotMatch
}

public class JSONRPCEngineMock: JSONRPCEngine {
    public var url: URL?
    public var connectionName: String?

    public var pendingEngineRequests: [SSFUtils.JSONRPCRequest] = []

    public init() {}

    public func subscribe<P: Encodable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 where P: Encodable, T: Decodable {
        UInt16.random(in: Range(1 ... 1000))
    }

    public var completionResult: Decodable?

    public func callMethod<P: Encodable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 where P: Encodable, T: Decodable {
        if let completionResult = completionResult {
            if let result = completionResult as? T {
                closure?(.success(result))
            } else {
                closure?(.failure(JSONRPCEngineMockError.typesDoNotMatch))
            }
        }
        return UInt16.random(in: Range(1 ... 1000))
    }

    public func cancelForIdentifier(_: UInt16) {}

    public func generateRequestId() -> UInt16 {
        UInt16.random(in: Range(1 ... 1000))
    }

    public func addSubscription(_: SSFUtils.JSONRPCSubscribing) {}

    public func connectIfNeeded() {}

    public func disconnectIfNeeded() {}

    public func unsubsribe(_: UInt16) {}

    public func unsubsribeAll() {}
}
