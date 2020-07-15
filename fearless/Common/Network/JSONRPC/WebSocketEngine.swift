import Foundation
import Starscream

final class WebSocketEngine {
    static let sharedCompletionQueue = DispatchQueue(label: "jp.co.soramitsu.fearless.websocket.shared",
                                                     attributes: .concurrent)

    struct PendingRequest: Equatable {
        let requestId: UInt16
        let data: Data
        let completionClosure: JSONRPCEngineClosure?

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
    private var inProgressRequests: [UInt16: PendingRequest] = [:]

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
        inProgressRequests[request.requestId] = request
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
            value.completionClosure?(.failure(error))
        }

        currentPendings.forEach { value in
            value.completionClosure?(.failure(error))
        }
    }

    private func process(data: Data) {
        do {
            let response = try jsonDecoder.decode(JSONRPCData.self, from: data)
            completeRequest(for: response)
        } catch {
            if let stringData = String(data: data, encoding: .utf8) {
                logger.error("Can't parse data: \(stringData)")
            } else {
                logger.error("Can't parse data")
            }
        }
    }

    private func completeRequest(for response: JSONRPCData) {
        mutex.lock()

        let completionClosure = inProgressRequests[response.identifier]?.completionClosure
        inProgressRequests[response.identifier] = nil

        mutex.unlock()

        if let result = response.result {
            completionClosure?(.success(result))
        } else {
            let error: Error = response.error ?? JSONRPCEngineError.emptyResult
            completionClosure?(.failure(error))
        }
    }
}

extension WebSocketEngine: JSONRPCEngine {
    func callMethod(_ method: String,
                    params: [String],
                    completion closure: JSONRPCEngineClosure?) throws -> UInt16 {
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

        let request = PendingRequest(requestId: currentRequestId, data: data, completionClosure: closure)

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

        pendingRequests = pendingRequests.filter { $0.requestId != identifier }
        let request = inProgressRequests[identifier]
        inProgressRequests[identifier] = nil

        mutex.unlock()

        if let completionClosure = request?.completionClosure {
            connection.callbackQueue.async {
                completionClosure(.failure(JSONRPCEngineError.clientCancelled))
            }
        }
    }
}

extension WebSocketEngine: WebSocketDelegate {
    func didReceive(event: WebSocketEvent, client: WebSocket) {
        switch event {
        case .binary(let data):
            process(data: data)
        case .text(let string):
            logger.debug("Did receive text: \(string)")
            if let data = string.data(using: .utf8) {
                process(data: data)
            } else {
                logger.warning("Unsupported text event: \(string)")
            }
        case .ping, .pong:
            break
        case .connected:
            logger.debug("connection established")

            mutex.lock()

            state = .connected

            mutex.unlock()

            sendAllPendingRequests()
        case .disconnected(let reason, let code):
            logger.warning("Disconnected with code \(code): \(reason)")

            mutex.lock()

            state = .notConnected

            mutex.unlock()

            completeAllWithError(JSONRPCError(message: reason, code: Int(code)))
        case .reconnectSuggested:
            logger.debug("reconnect suggested")
        case .viabilityChanged:
            logger.debug("viability changed")
        case .error(let error):
            if let error = error {
                logger.error("Did receive error: \(error)")
            } else {
                logger.error("Did receive unknown error")
            }
        case .cancelled:
            logger.warning("Remote cancelled")
        }
    }
}
