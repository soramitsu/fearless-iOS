import Foundation
@testable import fearless
import SSFUtils

// Minimal JSONRPCEngine stub used by tests
final class MockConnection: ChainConnection {
    var url: URL? = URL(string: "wss://mock")

    private(set) var pendingRequests: [JSONRPCRequest] = []

    var pendingEngineRequests: [JSONRPCRequest] { pendingRequests }

    func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        _ = (method, params, options)
        // Return a dummy id; no actual transport
        return 0
    }

    func subscribe<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        _ = (method, params, updateClosure, failureClosure)
        return 0
    }

    func cancelForIdentifier(_ identifier: UInt16) { _ = identifier }

    func generateRequestId() -> UInt16 { 0 }

    func addSubscription(_ subscription: JSONRPCSubscribing) { _ = subscription }

    func reconnect(url: URL) { self.url = url }

    func connectIfNeeded() {}

    func disconnectIfNeeded() {}

    func unsubsribe(_ identifier: UInt16) throws { _ = identifier }
}
