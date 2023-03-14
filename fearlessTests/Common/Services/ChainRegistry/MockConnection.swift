import Foundation
@testable import fearless
import FearlessUtils

final class MockConnection {
    let internalConnection = MockJSONRPCEngine()
}

extension MockConnection: ChainConnection {
    func connectIfNeeded() {
        
    }
    
    var pendingEngineRequests: [FearlessUtils.JSONRPCRequest] {
        []
    }
    
    func connect(with pendingRequests: [FearlessUtils.JSONRPCRequest]) {

    }
    
    func generateRequestId() -> UInt16 {
        0
    }
    
    func addSubscription(_ subscription: JSONRPCSubscribing) { }
    
    func disconnectIfNeeded() { }
    
    var url: URL? {
        get {
            internalConnection.url
        }
        set(newValue) { }
    }

    var state: WebSocketEngine.State {
        .connected
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
