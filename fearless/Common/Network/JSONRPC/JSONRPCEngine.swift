import Foundation

enum JSONRPCEngineError: Error {
    case emptyResult
    case remoteCancelled
    case clientCancelled
    case unknownError
}

protocol ResponseHandling {
    func handle(data: Data)
    func handle(error: Error)
}

struct ResponseHandler<T: Decodable>: ResponseHandling {
    let completionClosure: (Result<T, Error>) -> Void

    func handle(data: Data) {
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(JSONRPCData<T>.self, from: data)

            completionClosure(.success(response.result))

        } catch {
            completionClosure(.failure(error))
        }
    }

    func handle(error: Error) {
        completionClosure(.failure(error))
    }
}

struct JSONRPCOptions {
    let resendOnReconnect: Bool

    init(resendOnReconnect: Bool = true) {
        self.resendOnReconnect = resendOnReconnect
    }
}

protocol JSONRPCEngine: class {
    func callMethod<P: Encodable, T: Decodable>(_ method: String,
                                                params: P?,
                                                options: JSONRPCOptions,
                                                completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16
    func cancelForIdentifier(_ identifier: UInt16)
}

extension JSONRPCEngine {
    func callMethod<P: Encodable, T: Decodable>(_ method: String,
                                                params: P?,
                                                completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        try callMethod(method,
                       params: params,
                       options: JSONRPCOptions(),
                       completion: closure)
    }
}
