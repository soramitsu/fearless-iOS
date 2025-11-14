import Foundation
@testable import fearless
import SSFUtils

// Lightweight test double conforming to SSFUtils.JSONRPCEngine used by chain registry tests.
final class MockConnection: JSONRPCEngine {
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    private var nextId: UInt16 = 1
    private struct AnySubscription {
        let update: (Any) -> Void
        let failure: (Error, Bool) -> Void
    }

    private var subscriptions: [UInt16: AnySubscription] = [:]

    func callMethod<P: Codable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        let id = generateRequestId()
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
        subscriptions[id] = AnySubscription(
            update: { value in
                guard let typed = value as? T else {
                    return
                }

                updateClosure(typed)
            },
            failure: failureClosure
        )
        return id
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        subscriptions.removeValue(forKey: identifier)
    }

    func generateRequestId() -> UInt16 {
        defer { nextId &+= 1 }
        return nextId
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {}

    func reconnect(url: URL) { self.url = url }
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_ identifier: UInt16) throws {}

    // MARK: - Test helpers

    func emit<T>(_ value: T, for identifier: UInt16? = nil) {
        if let identifier {
            subscriptions[identifier]?.update(value)
        } else {
            subscriptions.values.forEach { $0.update(value) }
        }
    }

    func fail(_ error: Error, unsubscribed: Bool = false, identifier: UInt16? = nil) {
        if let identifier {
            subscriptions[identifier]?.failure(error, unsubscribed)
            return
        }

        subscriptions.values.forEach { $0.failure(error, unsubscribed) }
    }
}
