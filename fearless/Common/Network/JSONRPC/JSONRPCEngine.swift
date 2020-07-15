import Foundation

typealias JSONRPCEngineClosure = (Result<String, Error>) -> Void

enum JSONRPCEngineError: Error {
    case emptyResult
    case remoteCancelled
    case clientCancelled
    case unknownError
}

protocol JSONRPCEngine: class {
    func callMethod(_ method: String,
                    params: [String],
                    completion closure: JSONRPCEngineClosure?) throws -> UInt16
    func cancelForIdentifier(_ identifier: UInt16)
}
