import Foundation
@testable import fearless
import SSFUtils

final class MockConnection {
    let internalConnection = MockJSONRPCEngine()
}

extension MockConnection: JSONRPCEngine {
    var url: URL? {
        get { internalConnection.url }
        set { internalConnection.url = newValue }
    }

    var pendingEngineRequests: [JSONRPCRequest] { internalConnection.pendingEngineRequests }

    func reconnect(url: URL) {
        internalConnection.reconnect(url: url)
    }

    func connectIfNeeded() {
        internalConnection.connectIfNeeded()
    }

    func disconnectIfNeeded() {
        internalConnection.disconnectIfNeeded()
    }

    func connect(with pendingRequests: [JSONRPCRequest]) {
        // Forwarding connect helper (if needed in future tests)
        // No-op for now; tests use call/subscribe directly
    }

    func generateRequestId() -> UInt16 { internalConnection.generateRequestId() }

    func addSubscription(_ subscription: JSONRPCSubscribing) { internalConnection.addSubscription(subscription) }

    func callMethod<P, T>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 where P: Encodable, T: Decodable {
        try internalConnection.callMethod(
            method,
            params: params,
            options: options,
            completion: closure
        )
    }

    func subscribe<P, T>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 where P: Encodable, T: Decodable {
        try internalConnection.subscribe(
            method,
            params: params,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        internalConnection.cancelForIdentifier(identifier)
    }
}
