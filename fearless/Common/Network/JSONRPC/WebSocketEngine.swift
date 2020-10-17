import Foundation
import Starscream

protocol WebSocketConnectionProtocol: WebSocketClient {
    var callbackQueue: DispatchQueue { get set }
    var delegate: WebSocketDelegate? { get set }
}

extension WebSocket: WebSocketConnectionProtocol {}

final class WebSocketEngine {
    static let sharedCompletionQueue = DispatchQueue(label: "jp.co.soramitsu.fearless.websocket.shared",
                                                     attributes: .concurrent)

    struct Request: Equatable {
        let requestId: UInt16
        let data: Data
        let options: JSONRPCOptions
        let responseHandler: ResponseHandling?

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.requestId == rhs.requestId }
    }

    enum State {
        case notConnected
        case connecting(attempt: Int)
        case waitingReconnection(attempt: Int)
        case connected
    }

    let connection: WebSocketConnectionProtocol
    let version: String
    let logger: LoggerProtocol
    let reachabilityManager: ReachabilityManagerProtocol?

    private(set) var state: State = .notConnected

    private var requestId: UInt16 = 1
    private var mutex: NSLock = NSLock()
    private var jsonEncoder = JSONEncoder()
    private var jsonDecoder = JSONDecoder()
    private var reconnectionStrategy: ReconnectionStrategyProtocol?

    private lazy var reconnectionScheduler: SchedulerProtocol = {
        let scheduler = Scheduler(with: self, callbackQueue: connection.callbackQueue)
        return scheduler
    }()

    private var pendingRequests: [Request] = []
    private var inProgressRequests: [UInt16: Request] = [:]

    init(url: URL,
         reachabilityManager: ReachabilityManagerProtocol? = nil,
         reconnectionStrategy: ReconnectionStrategyProtocol? = ExponentialReconnection(),
         version: String = "2.0",
         completionQueue: DispatchQueue? = nil,
         autoconnect: Bool = true,
         connectionTimeout: TimeInterval = 10.0,
         logger: LoggerProtocol) {
        self.version = version
        self.logger = logger
        self.reconnectionStrategy = reconnectionStrategy
        self.reachabilityManager = reachabilityManager

        let request = URLRequest(url: url, timeoutInterval: connectionTimeout)

        let callbackQueue = completionQueue ?? Self.sharedCompletionQueue

        let engine = WSEngine(transport: FoundationTransport(),
                              certPinner: FoundationSecurity(),
                              compressionHandler: nil)

        let connection = WebSocket(request: request, engine: engine)
        connection.forceDisconnect()
        self.connection = connection

        connection.delegate = self

        connection.callbackQueue = callbackQueue

        subscribeToReachabilityStatus()

        if autoconnect {
            connectIfNeeded()
        }
    }

    init(connection: WebSocketConnectionProtocol,
         reachabilityManager: ReachabilityManagerProtocol? = nil,
         reconnectionStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
         version: String = "2.0",
         autoconnect: Bool = true,
         logger: LoggerProtocol) {
        self.connection = connection
        self.reachabilityManager = reachabilityManager
        self.reconnectionStrategy = reconnectionStrategy
        self.version = version
        self.logger = logger

        connection.delegate = self

        subscribeToReachabilityStatus()

        if autoconnect {
            connectIfNeeded()
        }
    }

    deinit {
        clearReachabilitySubscription()

        disconnectIfNeeded()
    }

    func connectIfNeeded() {
        mutex.lock()

        switch state {
        case .notConnected:
            startConnecting(0)

            logger.debug("Did start connecting to socket")
        case .waitingReconnection:
            reconnectionScheduler.cancel()

            startConnecting(0)

            logger.debug("Waiting for connection but decided to connect anyway")
        default:
            logger.debug("Already connecting to socket")
        }

        mutex.unlock()
    }

    func disconnectIfNeeded() {
        mutex.lock()

        let cancelledRequests: [Request]?

        switch state {
        case .connected:
            state = .notConnected

            cancelledRequests = resetInProgress()

            connection.disconnect(closeCode: CloseCode.goingAway.rawValue)

            logger.debug("Did start disconnect from socket")
        case .connecting:
            state = .notConnected

            cancelledRequests = nil

            connection.disconnect()

            logger.debug("Cancel socket connection")

        case .waitingReconnection:
            cancelledRequests = nil

            logger.debug("Cancel reconnection scheduler due to disconnection")
            reconnectionScheduler.cancel()
        default:
            cancelledRequests = nil

            logger.debug("Already disconnected from socket")
        }

        mutex.unlock()

        cancelledRequests?
            .forEach { $0.responseHandler?.handle(error: JSONRPCEngineError.clientCancelled)}
    }

    private func subscribeToReachabilityStatus() {
        do {
            try reachabilityManager?.add(listener: self)
        } catch {
            logger.warning("Failed to subscribe to reachability changes")
        }
    }

    private func clearReachabilitySubscription() {
        reachabilityManager?.remove(listener: self)
    }

    private func updateConnectionForRequest(_ request: Request) {
        switch state {
        case .connected:
            send(request: request)
        case .connecting:
            pendingRequests.append(request)
        case .notConnected:
            pendingRequests.append(request)

            startConnecting(0)
        case .waitingReconnection:
            logger.debug("Don't wait for reconnection for incoming request")

            pendingRequests.append(request)

            reconnectionScheduler.cancel()

            startConnecting(0)
        }
    }

    private func send(request: Request) {
        inProgressRequests[request.requestId] = request

        connection.write(data: request.data, completion: nil)
    }

    private func sendAllPendingRequests() {
        let currentPendings = pendingRequests
        pendingRequests = []

        for pending in currentPendings {
            logger.debug("Sending request with id: \(pending.requestId)")
            send(request: pending)
        }
    }

    private func resetInProgress() -> [Request] {
        let idempotentRequests = inProgressRequests.compactMap { $1.options.resendOnReconnect ? $1 : nil }

        let notifiableRequests = inProgressRequests.compactMap {
            !$1.options.resendOnReconnect && $1.responseHandler != nil ? $1 : nil
        }

        pendingRequests.append(contentsOf: idempotentRequests)
        inProgressRequests = [:]

        return notifiableRequests
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

        request?.responseHandler?.handle(data: data)
    }

    private func completeRequestForId(_ identifier: UInt16, error: Error) {
        mutex.lock()

        let request = inProgressRequests.removeValue(forKey: identifier)

        mutex.unlock()

        request?.responseHandler?.handle(error: error)
    }

    private func scheduleReconnectionOrDisconnect(_ attempt: Int, after error: Error? = nil) {
        if let reconnectionStrategy = reconnectionStrategy,
            let nextDelay = reconnectionStrategy.reconnectAfter(attempt: attempt - 1) {
            state = .waitingReconnection(attempt: attempt)

            logger.debug("Schedule reconnection with attempt \(attempt) and delay \(nextDelay)")

            reconnectionScheduler.notifyAfter(nextDelay)
        } else {
            state = .notConnected

            // notify pendings about error because there is no chance to reconnect

            let requests = pendingRequests
            pendingRequests = []

            let requestError = error ?? JSONRPCEngineError.unknownError
            requests.forEach { $0.responseHandler?.handle(error: requestError) }
        }
    }

    private func startConnecting(_ attempt: Int) {
        logger.debug("Start connecting with attempt: \(attempt)")

        state = .connecting(attempt: attempt)

        connection.connect()
    }
}

extension WebSocketEngine: JSONRPCEngine {

    func callMethod<P: Encodable, T: Decodable>(_ method: String,
                                                params: P?,
                                                options: JSONRPCOptions,
                                                completion closure: ((Result<T, Error>) -> Void)?) throws -> UInt16 {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let data: Data

        if let params = params {
            let info = JSONRPCInfo(identifier: requestId,
                                   jsonrpc: version,
                                   method: method,
                                   params: params)

            data = try jsonEncoder.encode(info)
        } else {
            let info = JSONRPCInfo(identifier: requestId,
                                   jsonrpc: version,
                                   method: method,
                                   params: [String]())

            data = try jsonEncoder.encode(info)
        }

        let currentRequestId = requestId

        let handler: ResponseHandling?

        if let completionClosure = closure {
            handler = ResponseHandler(completionClosure: completionClosure)
        } else {
            handler = nil
        }

        let request = Request(requestId: currentRequestId,
                              data: data,
                              options: options,
                              responseHandler: handler)

        requestId += 1

        if requestId == UInt16.max {
            requestId = 1
        }

        updateConnectionForRequest(request)

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
                request.responseHandler?.handle(error: JSONRPCEngineError.clientCancelled)
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
        case .connected:
            handleConnectedEvent()
        case .disconnected(let reason, let code):
            handleDisconnectedEvent(reason: reason, code: code)
        case .error(let error):
            handleErrorEvent(error)
        case .cancelled:
            handleCancelled()
        default:
            logger.warning("Unhandled event \(event)")
        }
    }

    private func handleCancelled() {
        logger.warning("Remote cancelled")

        var cancelledRequests: [Request]?

        mutex.lock()

        switch state {
        case .connecting(let attempt):
            connection.disconnect()
            scheduleReconnectionOrDisconnect(attempt + 1)
        case .connected:
            cancelledRequests = resetInProgress()

            connection.disconnect()
            scheduleReconnectionOrDisconnect(1)
        default:
            break
        }

        mutex.unlock()

        cancelledRequests?.forEach {
            $0.responseHandler?.handle(error: JSONRPCEngineError.clientCancelled)
        }
    }

    private func handleErrorEvent(_ error: Error?) {
        if let error = error {
            logger.error("Did receive error: \(error)")
        } else {
            logger.error("Did receive unknown error")
        }

        var cancelledRequests: [Request]?

        mutex.lock()

        switch state {
        case .connected:
            cancelledRequests = resetInProgress()

            connection.disconnect()
            startConnecting(0)
        case .connecting(let attempt):
            connection.disconnect()

            scheduleReconnectionOrDisconnect(attempt + 1)
        default:
            break
        }

        mutex.unlock()

        cancelledRequests?.forEach {
            $0.responseHandler?.handle(error: JSONRPCEngineError.clientCancelled)
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

        sendAllPendingRequests()

        mutex.unlock()
    }

    private func handleDisconnectedEvent(reason: String, code: UInt16) {
        logger.warning("Disconnected with code \(code): \(reason)")

        var cancelledRequests: [Request]?

        mutex.lock()

        switch state {
        case .connecting(let attempt):
            scheduleReconnectionOrDisconnect(attempt + 1)
        case .connected:
            cancelledRequests = resetInProgress()

            scheduleReconnectionOrDisconnect(1)
        default:
            break
        }

        mutex.unlock()

        cancelledRequests?.forEach {
            $0.responseHandler?.handle(error: JSONRPCEngineError.clientCancelled)
        }
    }
}

extension WebSocketEngine: SchedulerDelegate {
    func didTrigger(scheduler: SchedulerProtocol) {
        logger.debug("Did trigger reconnection scheduler")

        mutex.lock()

        if case .waitingReconnection(let attempt) = state {
            startConnecting(attempt)
        }

        mutex.unlock()
    }
}

extension WebSocketEngine: ReachabilityListenerDelegate {
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        if manager.isReachable, case .waitingReconnection = state {
            logger.debug("Network became reachable, retrying connection")

            reconnectionScheduler.cancel()
            startConnecting(0)
        }
    }
}
