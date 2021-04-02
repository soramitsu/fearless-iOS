import Foundation

extension WebSocketEngine: JSONRPCEngine {
    func callMethod<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let request = try prepareRequest(
            method: method,
            params: params,
            options: options,
            completion: closure
        )

        updateConnectionForRequest(request)

        return request.requestId
    }

    func subscribe<P: Encodable, T: Decodable>(
        _ method: String,
        params: P?,
        updateClosure: @escaping (T) -> Void,
        failureClosure: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let completion: ((Result<String, Error>) -> Void)? = nil

        let request = try prepareRequest(
            method: method,
            params: params,
            options: JSONRPCOptions(resendOnReconnect: true),
            completion: completion
        )

        let subscription = JSONRPCSubscription(
            requestId: request.requestId,
            requestData: request.data,
            requestOptions: request.options,
            updateClosure: updateClosure,
            failureClosure: failureClosure
        )

        addSubscription(subscription)

        updateConnectionForRequest(request)

        return request.requestId
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        mutex.lock()

        cancelRequestForLocalId(identifier)

        mutex.unlock()
    }
}
