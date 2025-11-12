import Foundation
@testable import fearless
import SSFUtils

// Lightweight test double conforming to SSFUtils.JSONRPCEngine used by chain registry tests.
final class MockConnection: JSONRPCEngine {
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private var nextId: UInt16 = 1

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let id = generateRequestId()
        // Immediately fail calls in tests that don’t expect networking
        closure?(.failure(JSONRPCEngineError.clientCancelled))
        return id
    }

    func subscribe<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        let id = generateRequestId()
        // Do not deliver updates; just track a pending subscription
        return id
    }

    func cancelForIdentifier(_ identifier: UInt16) {}

    func generateRequestId() -> UInt16 {
        defer { nextId &+= 1 }
        return nextId
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {}

    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}
}
