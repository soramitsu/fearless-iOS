import Foundation
import Starscream

extension WebSocketEngine: JSONRPCEngine {
    public var pendingEngineRequests: [JSONRPCRequest] {
        pendingRequests
    }

    public func callMethod<P: Codable, T: Decodable>(
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

    public func subscribe<P: Codable, T: Decodable>(
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

        guard addSubscriptionLocked(subscription) else { throw JSONRPCEngineError.unknownError }

        updateConnectionForRequest(request)

        return request.requestId
    }

    public func cancelForIdentifier(_ identifier: UInt16) {
        mutex.lock()

        cancelRequestForLocalId(identifier)

        mutex.unlock()
    }

    public func cancelForIdentifier(_ identifier: UInt16, writeAuthorization: JSONRPCWriteAuthorizing) {
        mutex.lock()
        defer { mutex.unlock() }
        let request = pendingRequests.first { $0.requestId == identifier } ?? inProgressRequests[identifier]
        if request?.options.writeAuthorization === writeAuthorization {
            cancelRequestForLocalId(identifier)
        } else if request == nil,
                  subscriptions[identifier]?.requestOptions.writeAuthorization === writeAuthorization {
            processSubscriptionError(identifier, error: JSONRPCEngineError.submissionOutcomeUnknown, shouldUnsubscribe: true)
        }
    }

    public func reconnect(url: URL) {
        mutex.lock()
        let shouldResume: Bool
        switch state {
        case .notConnected: shouldResume = false
        case .connecting, .connected, .waitingReconnection, .notReachable: shouldResume = true
        }
        cancelPendingGuardedRequests()
        let cancelled = resetInProgress()
        notify(requests: cancelled, error: JSONRPCEngineError.remoteCancelled)
        let previous = connection
        previous.delegate = nil
        reconnectionScheduler.cancel()
        pingScheduler.cancel()
        self.url = url
        let request = URLRequest(url: url, timeoutInterval: 10)
        // Reusing an already-connected engine would send a new URL's requests
        // to the previous socket. A new endpoint requires a new handshake.
        let next = replacementConnectionFactory?(request) ?? WebSocket(
            request: request, engine: WSEngine(transport: TCPTransport(), certPinner: FoundationSecurity())
        )
        next.callbackQueue = completionQueue
        next.delegate = self
        connection = next
        changeState(.notConnected)
        mutex.unlock()
        // No library writer wait occurs while holding the RPC request mutex.
        previous.forceDisconnect()
        // The previous retry timer belongs to the retired endpoint and was
        // cancelled above. Resume explicitly so pending reads/subscriptions do
        // not depend on an unrelated future request to connect the new URL.
        if shouldResume { connectIfNeeded() }
    }
}
