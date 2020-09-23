import Foundation
import Starscream

final class WebSocketEngine {
    static let sharedCompletionQueue = DispatchQueue(label: "jp.co.soramitsu.fearless.websocket.shared",
                                                     attributes: .concurrent)

    struct PendingRequest: Equatable {
        let requestId: UInt16
        let data: Data
        let responseHandler: ResponseHandling?

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.requestId == rhs.requestId }
    }

    struct InProgressRequest: Equatable {
        let requestId: UInt16
        let responseHandler: ResponseHandling

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.requestId == rhs.requestId }
    }

    enum State {
        case notConnected
        case connecting
        case connected
    }

    let connection: WebSocket
    let version: String
    let logger: LoggerProtocol

    private(set) var state: State = .notConnected

    private var requestId: UInt16 = 1
    private var mutex: NSLock = NSLock()
    private var jsonEncoder = JSONEncoder()
    private var jsonDecoder = JSONDecoder()

    private var pendingRequests: [PendingRequest] = []
    private var inProgressRequests: [UInt16: InProgressRequest] = [:]

    init(url: URL, version: String = "2.0", completionQueue: DispatchQueue? = nil, logger: LoggerProtocol) {
        self.version = version
        self.logger = logger

        let request = URLRequest(url: url)
        connection = WebSocket(request: request)
        connection.callbackQueue = completionQueue ?? Self.sharedCompletionQueue
        connection.delegate = self

        connect()
    }

    deinit {
        connection.forceDisconnect()
    }

    private func connect() {
        mutex.lock()

        state = .connecting

        mutex.unlock()

        connection.connect()
    }

    private func send(request: PendingRequest) {
        if let handler = request.responseHandler {
            inProgressRequests[request.requestId] = InProgressRequest(requestId: request.requestId,
                                                                      responseHandler: handler)
        }

        connection.write(data: request.data, completion: nil)
    }

    private func sendAllPendingRequests() {
        mutex.lock()

        let currentPendings = pendingRequests
        pendingRequests = []

        for pending in currentPendings {
            send(request: pending)
        }

        mutex.unlock()
    }

    private func completeAllWithError(_ error: Error) {
        mutex.lock()

        let currentInProgress = inProgressRequests
        inProgressRequests = [:]

        let currentPendings = pendingRequests
        pendingRequests = []

        mutex.unlock()

        currentInProgress.forEach { _, value in
            value.responseHandler.handle(error: error)
        }

        currentPendings.forEach { value in
            value.responseHandler?.handle(error: error)
        }
    }

    private func process(data: Data) {
        do {
            let response = try jsonDecoder.decode(JSONRPCBasicData.self, from: data)

            if let error = response.error {
                completeRequestForId(response.identifier, error: error)
            } else {
                completeRequestForId(response.identifier, data: data)
            }
        } catch {
            if let stringData = String(data: data, encoding: .utf8) {
                logger.error("Can't parse data: \(stringData)")
            } else {
                logger.error("Can't parse data")
            }
        }
    }

    private func completeRequestForId(_ identifier: UInt16, data: Data) {
        mutex.lock()

        let request = inProgressRequests.removeValue(forKey: identifier)

        mutex.unlock()

        request?.responseHandler.handle(data: data)
    }

    private func completeRequestForId(_ identifier: UInt16, error: Error) {
        mutex.lock()

        let request = inProgressRequests.removeValue(forKey: identifier)

        mutex.unlock()

        request?.responseHandler.handle(error: error)
    }
}

extension WebSocketEngine: JSONRPCEngine {
    func callMethod<T: Decodable>(_ method: String,
                                  params: [String],
                                  completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let info = JSONRPCInfo(identifier: requestId,
                               jsonrpc: version,
                               method: method,
                               params: params)

        let data = try jsonEncoder.encode(info)

        let currentRequestId = requestId

        let handler: ResponseHandling?

        if let completionClosure = closure {
            handler = ResponseHandler(completionClosure: completionClosure)
        } else {
            handler = nil
        }

        let request = PendingRequest(requestId: currentRequestId, data: data, responseHandler: handler)

        requestId += 1

        if requestId == UInt16.max {
            requestId = 1
        }

        switch state {
        case .connected:
            send(request: request)
        case .connecting:
            pendingRequests.append(request)
        case .notConnected:
            pendingRequests.append(request)

            state = .connecting

            connection.connect()
        }

        return currentRequestId
    }

    func cancelForIdentifier(_ identifier: UInt16) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let index = pendingRequests.firstIndex(where: { $0.requestId == identifier }) {
            let request = pendingRequests.remove(at: index)

            connection.callbackQueue.async {
                request.responseHandler?.handle(error: JSONRPCEngineError.clientCancelled)
            }

            return
        }

        if let request = inProgressRequests.removeValue(forKey: identifier) {
            connection.callbackQueue.async {
                request.responseHandler.handle(error: JSONRPCEngineError.clientCancelled)
            }
        }
    }
}

extension WebSocketEngine: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .binary(let data):
            handleBinaryEvent(data: data)
        case .text(let string):
            handleTextEvent(string: string)
        case .ping, .pong:
            break
        case .connected:
            handleConnectedEvent()
        case .disconnected(let reason, let code):
            handleDisconnectedEvent(reason: reason, code: code)
        case .reconnectSuggested:
            logger.debug("reconnect suggested")
        case .viabilityChanged:
            logger.debug("viability changed")
        case .error(let error):
            handleErrorEvent(error)
        case .cancelled:
            logger.warning("Remote cancelled")
        }
    }

    private func handleErrorEvent(_ error: Error?) {
        if let error = error {
            logger.error("Did receive error: \(error)")
        } else {
            logger.error("Did receive unknown error")
        }

        if state != .connected {
            let completionError = error ?? JSONRPCError(message: "Uknown error", code: 0)
            completeAllWithError(completionError)
        }
    }

    private func handleBinaryEvent(data: Data) {
        if let decodedString = String(data: data, encoding: .utf8) {
            logger.debug("Did receive data: \(decodedString)")
        }

        process(data: data)
    }

    private func handleTextEvent(string: String) {
        logger.debug("Did receive text: \(string)")
        if let data = string.data(using: .utf8) {
            process(data: data)
        } else {
            logger.warning("Unsupported text event: \(string)")
        }
    }

    private func handleConnectedEvent() {
        logger.debug("connection established")

        mutex.lock()

        state = .connected

        mutex.unlock()

        sendAllPendingRequests()
    }

    private func handleDisconnectedEvent(reason: String, code: UInt16) {
        logger.warning("Disconnected with code \(code): \(reason)")

        mutex.lock()

        state = .notConnected

        mutex.unlock()

        completeAllWithError(JSONRPCError(message: reason, code: Int(code)))
    }
}
