import Foundation
@testable import fearless
import FearlessUtils

final class MockConnection {
    let internalConnection = MockJSONRPCEngine()
    let autobalancing = MockConnectionAutobalancing()
    let stateReporting = MockConnectionStateReporting()
}

extension MockConnection: ChainConnection {
    var ranking: [ConnectionRank] {
        autobalancing.ranking
    }

    func set(ranking: [ConnectionRank]) {
        autobalancing.set(ranking: ranking)
    }

    var state: WebSocketEngine.State {
        stateReporting.state
    }

    func callMethod<P, T>(_ method: String, params: P?, options: JSONRPCOptions, completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 where P : Encodable, T : Decodable {
        try internalConnection.callMethod(
            method,
            params: params,
            options: options,
            completion: closure
        )
    }

    func subscribe<P, T>(_ method: String, params: P?, updateClosure: @escaping (T) -> Void, failureClosure: @escaping (Error, Bool) -> Void) throws -> UInt16 where P : Encodable, T : Decodable {
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
