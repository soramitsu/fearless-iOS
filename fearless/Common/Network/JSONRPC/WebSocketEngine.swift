import Foundation
import Starscream

protocol WebSocketConnectionProtocol: WebSocketClient {
    var callbackQueue: DispatchQueue { get }
    var delegate: WebSocketDelegate? { get set }
}

extension WebSocket: WebSocketConnectionProtocol {}

protocol WebSocketEngineDelegate: AnyObject {
    func webSocketDidChangeState(
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    )
}

final class WebSocketEngine {
    static let sharedProcessingQueue = DispatchQueue(label: "jp.co.soramitsu.fearless.ws.processing")

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
    let completionQueue: DispatchQueue
    let pingInterval: TimeInterval

    private(set) var state: State = .notConnected {
        didSet {
            if let delegate = delegate {
                let oldState = oldValue
                let newState = state

                completionQueue.async {
                    delegate.webSocketDidChangeState(from: oldState, to: newState)
                }
            }
        }
    }

    let mutex = NSLock()
    private let jsonEncoder = JSONEncoder()
    private let jsonDecoder = JSONDecoder()
    private let reconnectionStrategy: ReconnectionStrategyProtocol?

    private(set) lazy var reconnectionScheduler: SchedulerProtocol = {
        let scheduler = Scheduler(with: self, callbackQueue: connection.callbackQueue)
        return scheduler
    }()

    private(set) lazy var pingScheduler: SchedulerProtocol = {
        let scheduler = Scheduler(with: self, callbackQueue: connection.callbackQueue)
        return scheduler
    }()

    private(set) var pendingRequests: [JSONRPCRequest] = []
    private(set) var inProgressRequests: [UInt16: JSONRPCRequest] = [:]
    private(set) var subscriptions: [UInt16: JSONRPCSubscribing] = [:]

    weak var delegate: WebSocketEngineDelegate?

    init(
        url: URL,
        reachabilityManager: ReachabilityManagerProtocol? = nil,
        reconnectionStrategy: ReconnectionStrategyProtocol? = ExponentialReconnection(),
        version: String = "2.0",
        processingQueue: DispatchQueue? = nil,
        autoconnect: Bool = true,
        connectionTimeout: TimeInterval = 10.0,
        pingInterval: TimeInterval = 30,
        logger: LoggerProtocol
    ) {
        self.version = version
        self.logger = logger
        self.reconnectionStrategy = reconnectionStrategy
        self.reachabilityManager = reachabilityManager
        completionQueue = processingQueue ?? Self.sharedProcessingQueue
        self.pingInterval = pingInterval

        let request = URLRequest(url: url, timeoutInterval: connectionTimeout)

        let engine = WSEngine(
            transport: FoundationTransport(),
            certPinner: FoundationSecurity(),
            compressionHandler: nil
        )

        let connection = WebSocket(request: request, engine: engine)
        connection.forceDisconnect()
        self.connection = connection

        connection.delegate = self

        connection.callbackQueue = processingQueue ?? Self.sharedProcessingQueue

        subscribeToReachabilityStatus()

        if autoconnect {
            connectIfNeeded()
        }
    }

    init(
        connection: WebSocketConnectionProtocol,
        reachabilityManager: ReachabilityManagerProtocol? = nil,
        reconnectionStrategy: ReconnectionStrategyProtocol = ExponentialReconnection(),
        version: String = "2.0",
        autoconnect: Bool = true,
        pingInterval: TimeInterval = 30,
        logger: LoggerProtocol
    ) {
        self.connection = connection
        self.reachabilityManager = reachabilityManager
        self.reconnectionStrategy = reconnectionStrategy
        self.version = version
        self.logger = logger
        completionQueue = Self.sharedProcessingQueue
        self.pingInterval = pingInterval

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

        switch state {
        case .connected:
            state = .notConnected

            let cancelledRequests = resetInProgress()

            connection.disconnect(closeCode: CloseCode.goingAway.rawValue)

            notify(
                requests: cancelledRequests,
                error: JSONRPCEngineError.clientCancelled
            )

            pingScheduler.cancel()

            logger.debug("Did start disconnect from socket")
        case .connecting:
            state = .notConnected

            connection.disconnect()

            logger.debug("Cancel socket connection")

        case .waitingReconnection:
            logger.debug("Cancel reconnection scheduler due to disconnection")
            reconnectionScheduler.cancel()
        default:
            logger.debug("Already disconnected from socket")
        }

        mutex.unlock()
    }
}

// MARK: Internal

extension WebSocketEngine {
    func changeState(_ newState: State) {
        state = newState
    }

    func subscribeToReachabilityStatus() {
        do {
            try reachabilityManager?.add(listener: self)
        } catch {
            logger.warning("Failed to subscribe to reachability changes")
        }
    }

    func clearReachabilitySubscription() {
        reachabilityManager?.remove(listener: self)
    }

    func updateConnectionForRequest(_ request: JSONRPCRequest) {
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

    func send(request: JSONRPCRequest) {
        inProgressRequests[request.requestId] = request

        connection.write(stringData: request.data, completion: nil)
    }

    func sendAllPendingRequests() {
        let currentPendings = pendingRequests
        pendingRequests = []

        for pending in currentPendings {
            logger.debug("Sending request with id: \(pending.requestId)")
            logger.debug("\(String(data: pending.data, encoding: .utf8)!)")
            send(request: pending)
        }
    }

    func resetInProgress() -> [JSONRPCRequest] {
        let idempotentRequests: [JSONRPCRequest] = inProgressRequests.compactMap {
            $1.options.resendOnReconnect ? $1 : nil
        }

        let notifiableRequests = inProgressRequests.compactMap {
            !$1.options.resendOnReconnect && $1.responseHandler != nil ? $1 : nil
        }

        pendingRequests.append(contentsOf: idempotentRequests)
        inProgressRequests = [:]

        rescheduleActiveSubscriptions()

        return notifiableRequests
    }

    func rescheduleActiveSubscriptions() {
        let activeSubscriptions = subscriptions.compactMap {
            $1.remoteId != nil ? $1 : nil
        }

        for subscription in activeSubscriptions {
            subscription.remoteId = nil
        }

        let subscriptionRequests: [JSONRPCRequest] = activeSubscriptions.enumerated().map {
            JSONRPCRequest(
                requestId: $1.requestId,
                data: $1.requestData,
                options: $1.requestOptions,
                responseHandler: nil
            )
        }

        pendingRequests.append(contentsOf: subscriptionRequests)
    }

    func process(data: Data) {
        do {
            let response = try jsonDecoder.decode(JSONRPCBasicData.self, from: data)

            if let identifier = response.identifier {
                if let error = response.error {
                    completeRequestForRemoteId(
                        identifier,
                        error: error
                    )
                } else {
                    completeRequestForRemoteId(
                        identifier,
                        data: data
                    )
                }
            } else {
                try processSubscriptionUpdate(data)
            }
        } catch {
            if let stringData = String(data: data, encoding: .utf8) {
                logger.error("Can't parse data: \(stringData)")
            } else {
                logger.error("Can't parse data")
            }
        }
    }

    func addSubscription(_ subscription: JSONRPCSubscribing) {
        subscriptions[subscription.requestId] = subscription
    }

    func prepareRequest<P: Encodable, T: Decodable>(
        method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    )
        throws -> JSONRPCRequest {
        let data: Data

        let requestId = generateRequestId()

        if let params = params {
            let info = JSONRPCInfo(
                identifier: requestId,
                jsonrpc: version,
                method: method,
                params: params
            )

            data = try jsonEncoder.encode(info)
        } else {
            let info = JSONRPCInfo(
                identifier: requestId,
                jsonrpc: version,
                method: method,
                params: [String]()
            )

            data = try jsonEncoder.encode(info)
        }

        let handler: JSONRPCResponseHandling?

        if let completionClosure = closure {
            handler = JSONRPCResponseHandler(completionClosure: completionClosure)
        } else {
            handler = nil
        }

        let request = JSONRPCRequest(
            requestId: requestId,
            data: data,
            options: options,
            responseHandler: handler
        )

        return request
    }

    func generateRequestId() -> UInt16 {
        let items = pendingRequests.map(\.requestId) + inProgressRequests.map(\.key)
        let existingIds: Set<UInt16> = Set(items)

        var targetId = (1 ... UInt16.max).randomElement() ?? 1

        while existingIds.contains(targetId) {
            targetId += 1
        }

        return targetId
    }

    func cancelRequestForLocalId(_ identifier: UInt16) {
        if let index = pendingRequests.firstIndex(where: { $0.requestId == identifier }) {
            let request = pendingRequests.remove(at: index)

            notify(
                requests: [request],
                error: JSONRPCEngineError.clientCancelled
            )
        } else if let request = inProgressRequests.removeValue(forKey: identifier) {
            notify(
                requests: [request],
                error: JSONRPCEngineError.clientCancelled
            )
        }
    }

    func completeRequestForRemoteId(_ identifier: UInt16, data: Data) {
        if let request = inProgressRequests.removeValue(forKey: identifier) {
            notify(request: request, data: data)
        }

        if subscriptions[identifier] != nil {
            processSubscriptionResponse(identifier, data: data)
        }
    }

    func processSubscriptionResponse(_ identifier: UInt16, data: Data) {
        do {
            let response = try jsonDecoder.decode(JSONRPCData<String>.self, from: data)
            subscriptions[identifier]?.remoteId = response.result

            logger.debug("Did receive subscription id: \(response.result)")
        } catch {
            processSubscriptionError(identifier, error: error, shouldUnsubscribe: true)

            if let responseString = String(data: data, encoding: .utf8) {
                logger.error("Did fail to parse subscription data: \(responseString)")
            } else {
                logger.error("Did fail to parse subscription data")
            }
        }
    }

    func processSubscriptionUpdate(_ data: Data) throws {
        let basicResponse = try jsonDecoder.decode(
            JSONRPCSubscriptionBasicUpdate.self,
            from: data
        )
        let remoteId = basicResponse.params.subscription

        if let (_, subscription) = subscriptions
            .first(where: { $1.remoteId == remoteId }) {
            logger.debug("Did receive update for subscription: \(remoteId)")

            completionQueue.async {
                try? subscription.handle(data: data)
            }
        } else {
            logger.warning("No handler for subscription: \(remoteId)")
        }
    }

    func completeRequestForRemoteId(_ identifier: UInt16, error: Error) {
        if let request = inProgressRequests.removeValue(forKey: identifier) {
            notify(requests: [request], error: error)
        }

        if subscriptions[identifier] != nil {
            processSubscriptionError(identifier, error: error, shouldUnsubscribe: true)
        }
    }

    func processSubscriptionError(_ identifier: UInt16, error: Error, shouldUnsubscribe: Bool) {
        if let subscription = subscriptions[identifier] {
            if shouldUnsubscribe {
                subscriptions.removeValue(forKey: identifier)
            }

            connection.callbackQueue.async {
                subscription.handle(error: error, unsubscribed: shouldUnsubscribe)
            }
        }
    }

    func notify(request: JSONRPCRequest, data: Data) {
        completionQueue.async {
            request.responseHandler?.handle(data: data)
        }
    }

    func notify(requests: [JSONRPCRequest], error: Error) {
        guard !requests.isEmpty else {
            return
        }

        completionQueue.async {
            requests.forEach {
                $0.responseHandler?.handle(error: error)
            }
        }
    }

    func scheduleReconnectionOrDisconnect(_ attempt: Int, after error: Error? = nil) {
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

    func schedulePingIfNeeded() {
        guard pingInterval > 0.0, case .connected = state else {
            return
        }

        logger.debug("Schedule socket ping")

        pingScheduler.notifyAfter(pingInterval)
    }

    func sendPing() {
        guard case .connected = state else {
            logger.warning("Tried to send ping but not connected")
            return
        }

        logger.debug("Sending socket ping")

        do {
            let options = JSONRPCOptions(resendOnReconnect: false)
            _ = try callMethod(
                RPCMethod.helthCheck,
                params: [String](),
                options: options
            ) { [weak self] (result: Result<Health, Error>) in
                self?.handlePing(result: result)
            }
        } catch {
            logger.error("Did receive ping error: \(error)")
        }
    }

    func handlePing(result: Result<Health, Error>) {
        switch result {
        case let .success(health):
            if health.isSyncing {
                logger.warning("Node is not healthy")
            }
        case let .failure(error):
            logger.error("Health check error: \(error)")
        }
    }

    func startConnecting(_ attempt: Int) {
        logger.debug("Start connecting with attempt: \(attempt)")

        state = .connecting(attempt: attempt)

        connection.connect()
    }
}
