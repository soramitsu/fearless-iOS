import Foundation
import SSFUtils

extension JSONRPCOperation {
    static func failureOperation(_ error: Error) -> JSONRPCOperation<P, T> {
        let operation = JSONRPCOperation<P, T>(engine: nil, method: "", parameters: nil, timeout: 0)
        operation.result = .failure(error)
        return operation
    }
}
