import Foundation
import SSFUtils

extension JSONRPCOperation {
    static func failureOperation(_ error: Error) -> JSONRPCOperation<P, T> {
        // Align with SSFUtils initializer by providing a dummy engine
        let engine = WebSocketEngine(connectionName: nil, url: URL(string: "https://wiki.fearlesswallet.io")!, autoconnect: false)
        let operation = JSONRPCOperation<P, T>(engine: engine, method: "")
        operation.result = .failure(error)
        return operation
    }
}
