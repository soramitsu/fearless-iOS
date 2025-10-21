import Foundation
import SSFUtils

final class MockJSONRPCEngine: JSONRPCEngine {
    var url: URL? = URL(string: "wss://mock")

    @discardableResult
    func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        // Return a dummy id and never call completion by default
        _ = (method, params, options)
        return 0
    }

    @discardableResult
    func subscribe<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        _ = (method, params, updateClosure, failureClosure)
        return 0
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        _ = identifier
    }
}

