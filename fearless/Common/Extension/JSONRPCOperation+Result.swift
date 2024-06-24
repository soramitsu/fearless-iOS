import Foundation
import SSFUtils

extension JSONRPCOperation {
    static func failureOperation(_ error: Error) -> JSONRPCOperation<P, T> {
        let mockEngine = try! WebSocketEngine(
            connectionName: nil,
            urls: [ApplicationConfig.shared.wiki],
            autoconnect: false
        )
        let operation = JSONRPCOperation<P, T>(engine: mockEngine, method: "")
        operation.result = .failure(error)
        return operation
    }
}
