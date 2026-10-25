import Foundation
import SSFModels
import Starscream

public protocol WebSocketConnectionProtocol: WebSocketClient {
    var callbackQueue: DispatchQueue { get }
    var delegate: WebSocketDelegate? { get set }

    func forceDisconnect()
}

extension WebSocket: WebSocketConnectionProtocol {}

public protocol WebSocketEngineDelegate: AnyObject {
    func webSocketDidChangeState(
        engine: WebSocketEngine,
        from oldState: WebSocketEngine.State,
        to newState: WebSocketEngine.State
    )
}

public final class WebSocketEngine {
    public static let sharedProcessingQueue =
        DispatchQueue(label: "jp.co.soramitsu.fearless.ws.processing")

    public enum State {
        case notConnected
        case connecting(attempt: Int)
        case waitingReconnection(attempt: Int)
        case connected
        case notReachable
    }

    public var connection: WebSocketConnectionProtocol
    // Internal fixture seam for source/app integration tests. Shipping callers
    // cannot override transport qualification; nil always creates fresh TCP.
    var replacementConnectionFactory: ((URLRequest) -> WebSocket)?
    public let version: String
    public let logger: SDKLoggerProtocol?
    public let reachabilityManager: ReachabilityManagerProtocol?
    public let completionQueue: DispatchQueue
    private let stateCallbackQueue: DispatchQueue
    private var stateRevision: UInt64 = 0
    public let pingInterval: TimeInterval

    public private(set) var state: State = .notConnected {
        didSet {
            stateRevision &+= 1
            if let delegate = delegate {
                let oldState = oldValue
                let newState = state
                let revision = stateRevision
                // State changes normally occur under the request mutex. A
                // failover delegate can replace the URL or enqueue another
                // request; deliver it on the ordered callback queue after the
                // current transition has released that nonrecursive mutex.
                stateCallbackQueue.async { [weak self, weak delegate] in
                    guard let self = self, let delegate = delegate else { return }
                    self.mutex.lock()
                    let current = self.stateRevision == revision && self.delegate === delegate
                    self.mutex.unlock()
                    // Suppress already-superseded queued transitions. State
                    // can still change after this check; the delegate is never
                    // invoked while holding the request mutex.
                    guard current else { return }
                    delegate.webSocketDidChangeState(engine: self, from: oldState, to: newState)
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
    private struct GuardedRequest {
        let generation: UUID
        let write: AuthorizedWrite
    }
    private var guardedRequests: [UInt16: GuardedRequest] = [:]
    private(set) var subscriptions: [UInt16: JSONRPCSubscribing] = [:]
    private var reservedRequestIds = Set<UInt16>()
    private(set) var unknownResponsesByRemoteId: [String: [Data]] = [:]

    public weak var delegate: WebSocketEngineDelegate?
    public var url: URL?
    public var connectionName: String?

    public init(
        connectionName: String?,
        url: URL,
        reachabilityManager: ReachabilityManagerProtocol? = ReachabilityManager.shared,
        reconnectionStrategy: ReconnectionStrategyProtocol? = ExponentialReconnection(),
        version: String = "2.0",
        processingQueue: DispatchQueue? = nil,
        autoconnect: Bool = true,
        connectionTimeout: TimeInterval = 10.0,
        pingInterval: TimeInterval = 30,
        logger: SDKLoggerProtocol? = nil
    ) {
        self.connectionName = connectionName
        self.url = url
        self.version = version
        self.logger = logger
        self.reconnectionStrategy = reconnectionStrategy
        self.reachabilityManager = reachabilityManager
        let callbackQueue = processingQueue ?? Self.sharedProcessingQueue
        completionQueue = callbackQueue
        stateCallbackQueue = DispatchQueue(label: "jp.co.soramitsu.fearless.ws.state", target: callbackQueue)
        self.pingInterval = pingInterval

        let request = URLRequest(url: url, timeoutInterval: connectionTimeout)

        let engine = WSEngine(transport: TCPTransport(), certPinner: FoundationSecurity())

        let connection = WebSocket(request: request, engine: engine)
        self.connection = connection

        connection.delegate = self

        connection.callbackQueue = processingQueue ?? Self.sharedProcessingQueue

        subscribeToReachabilityStatus()

        if autoconnect {
            connectIfNeeded()
        }
    }

    deinit {
        clearReachabilitySubscription()

        disconnectIfNeeded()
    }

    public func connectIfNeeded() {
        mutex.lock()

        switch state {
        case .notConnected:
            startConnecting(0)

            logger?.debug("Did start connecting to socket")
        case .waitingReconnection:
            reconnectionScheduler.cancel()

            startConnecting(0)

            logger?.debug("Waiting for connection but decided to connect anyway")
        default:
            logger?.debug("Already connecting to socket")
        }

        mutex.unlock()
    }

    public func disconnectIfNeeded() {
        mutex.lock()
        cancelPendingGuardedRequests()

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

            logger?.debug("Did start disconnect from socket")
        case .connecting:
            state = .notConnected

            connection.disconnect()

            logger?.debug("Cancel socket connection")

        case .waitingReconnection:
            state = .notConnected
            logger?.debug("Cancel reconnection scheduler due to disconnection")
            reconnectionScheduler.cancel()
        case .notReachable:
            state = .notConnected
            reconnectionScheduler.cancel()
            connection.disconnect()
        default:
            logger?.debug("Already disconnected from socket")
        }

        mutex.unlock()
    }

    public func unsubsribe(_ identifier: UInt16) throws {
        try processUnsubscription(identifier)
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
            logger?.warning("Failed to subscribe to reachability changes")
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
            logger?.debug("Don't wait for reconnection for incoming request")

            pendingRequests.append(request)

            reconnectionScheduler.cancel()

            startConnecting(0)
        case .notReachable:
            pendingRequests.append(request)
        }
    }

    func send(request: JSONRPCRequest) {
        inProgressRequests[request.requestId] = request
        guard let authorization = request.options.writeAuthorization else {
            connection.write(stringData: request.data, completion: nil)
            return
        }
        let generation = UUID()
        let write = connection.write(stringData: request.data,
                                     authorization: RPCWriteAuthorization(authorization),
                                     callbackQueue: completionQueue) { [weak self] result in
            guard let self = self else { return }
            self.mutex.lock()
            defer { self.mutex.unlock() }
            // A delayed old transport callback cannot cancel a reused UInt16 ID.
            guard self.guardedRequests[request.requestId]?.generation == generation else { return }
            if case .failure(let error) = result {
                self.guardedRequests.removeValue(forKey: request.requestId)
                if let request = self.inProgressRequests.removeValue(forKey: request.requestId) {
                    let resolved: Error = (error as? AuthorizedWriteError) == .outcomeUnknown
                        ? JSONRPCEngineError.submissionOutcomeUnknown : error
                    self.notify(requests: [request], error: resolved)
                    self.processSubscriptionError(request.requestId, error: resolved, shouldUnsubscribe: true)
                }
            }
            // Keep successful transport handles until the RPC result. Accepted
            // bytes without a terminal response remain an unknown transaction.
        }
        guardedRequests[request.requestId] = GuardedRequest(generation: generation, write: write)
    }

    private func cancelGuardedRequest(_ identifier: UInt16) -> JSONRPCEngineError? {
        guard let guarded = guardedRequests.removeValue(forKey: identifier) else { return nil }
        return guarded.write.cancel() == .notHandedOff ? .requestNotSent : .submissionOutcomeUnknown
    }

    func cancelPendingGuardedRequests() {
        let cancelled = pendingRequests.filter { $0.options.writeAuthorization != nil }
        pendingRequests.removeAll { $0.options.writeAuthorization != nil }
        notify(requests: cancelled, error: JSONRPCEngineError.requestNotSent)
        for request in cancelled {
            processSubscriptionError(request.requestId, error: JSONRPCEngineError.requestNotSent, shouldUnsubscribe: true)
        }
    }

    func sendAllPendingRequests() {
        let currentPendings = pendingRequests
        pendingRequests = []

        for pending in currentPendings {
            logger?.debug("Sending request with id: \(pending.requestId)")
            if pending.options.writeAuthorization == nil {
                logger?.debug("\(String(data: pending.data, encoding: .utf8)!)")
            }
            send(request: pending)
        }
    }

    func resetInProgress() -> [JSONRPCRequest] {
        let guarded = inProgressRequests.values.filter { $0.options.writeAuthorization != nil }
        for request in guarded {
            let error = cancelGuardedRequest(request.requestId) ?? .submissionOutcomeUnknown
            inProgressRequests.removeValue(forKey: request.requestId)
            notify(requests: [request], error: error)
            processSubscriptionError(request.requestId, error: error, shouldUnsubscribe: true)
        }
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
    
    func resetPendings() {
        pendingRequests = []
    }

    func rescheduleActiveSubscriptions() {
        let guarded = subscriptions.values.filter { $0.requestOptions.writeAuthorization != nil }
        for subscription in guarded {
            processSubscriptionError(subscription.requestId, error: JSONRPCEngineError.submissionOutcomeUnknown, shouldUnsubscribe: true)
        }
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
                logger?.error("Can't parse data: \(stringData)")
            } else {
                logger?.error("Can't parse data")
            }
        }
    }

    public func addSubscription(_ subscription: JSONRPCSubscribing) {
        mutex.lock()
        let accepted = addSubscriptionLocked(subscription)
        mutex.unlock()
        if !accepted {
            completionQueue.async {
                subscription.handle(error: JSONRPCEngineError.unknownError, unsubscribed: true)
            }
        }
    }

    // subscribe() already owns mutex while preparing and registering its RPC.
    // Public manual watchers reserve an ID before constructing a subscription.
    @discardableResult
    func addSubscriptionLocked(_ subscription: JSONRPCSubscribing) -> Bool {
        let identifier = subscription.requestId
        guard identifier != 0 else { return false }
        if let existing = subscriptions[identifier] { return existing === subscription }
        guard inProgressRequests[identifier] == nil,
              !pendingRequests.contains(where: { $0.requestId == identifier }) else { return false }
        reservedRequestIds.remove(identifier)
        subscriptions[identifier] = subscription
        return true
    }

    func prepareRequest<P: Codable, T: Decodable>(
        method: String,
        params: P?,
        options: JSONRPCOptions,
        completion closure: ((Result<T, Error>) -> Void)?
    )
        throws -> JSONRPCRequest
    {
        let data: Data

        let requestId = generateRequestIdLocked()
        // Zero is reserved for exhaustion; never encode an identifier that
        // could settle or cancel another active request/subscription.
        guard requestId != 0 else { throw JSONRPCEngineError.unknownError }

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

    public func generateRequestId() -> UInt16 {
        mutex.lock()
        defer { mutex.unlock() }
        let identifier = generateRequestIdLocked()
        if identifier != 0 { reservedRequestIds.insert(identifier) }
        return identifier
    }

    // Internal request preparation already owns mutex; public callers use the
    // synchronized wrapper above without recursively acquiring NSLock.
    private func generateRequestIdLocked() -> UInt16 {
        let items = pendingRequests.map(\.requestId) + inProgressRequests.map(\.key) + subscriptions.map(\.key)
        let existingIds = Set(items).union(reservedRequestIds)
        let start = Int((1 ... UInt16.max).randomElement() ?? 1)
        // Bound the search even if an endpoint retains the whole ID space.
        // Recursive random retries could exhaust the stack for a dense pool.
        for offset in 0 ..< Int(UInt16.max) {
            let candidate = UInt16((start - 1 + offset) % Int(UInt16.max) + 1)
            if !existingIds.contains(candidate) { return candidate }
        }
        return 0
    }

    func cancelRequestForLocalId(_ identifier: UInt16) {
        if let index = pendingRequests.firstIndex(where: { $0.requestId == identifier }) {
            let request = pendingRequests.remove(at: index)

            notify(
                requests: [request],
                error: request.options.writeAuthorization == nil ? JSONRPCEngineError.clientCancelled : JSONRPCEngineError.requestNotSent
            )
            if request.options.writeAuthorization != nil {
                processSubscriptionError(identifier, error: JSONRPCEngineError.requestNotSent, shouldUnsubscribe: true)
            }
        } else if let request = inProgressRequests.removeValue(forKey: identifier) {
            let error = cancelGuardedRequest(identifier) ?? JSONRPCEngineError.clientCancelled
            notify(requests: [request], error: error)
            if request.options.writeAuthorization != nil {
                processSubscriptionError(identifier, error: error, shouldUnsubscribe: true)
            }
        }
    }

    func completeRequestForRemoteId(_ identifier: UInt16, data: Data) {
        if cancelGuardedRequest(identifier) == .requestNotSent {
            if let request = inProgressRequests.removeValue(forKey: identifier) {
                notify(requests: [request], error: JSONRPCEngineError.requestNotSent)
            }
            processSubscriptionError(identifier, error: JSONRPCEngineError.requestNotSent, shouldUnsubscribe: true)
            return
        }
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

            if let postponed = unknownResponsesByRemoteId[response.result] {
                for data in postponed {
                    try processSubscriptionUpdate(data)
                }

                unknownResponsesByRemoteId[response.result] = nil
            }

            logger?.debug("Did receive subscription id: \(response.result)")
        } catch {
            processSubscriptionError(identifier, error: error, shouldUnsubscribe: true)

            if let responseString = String(data: data, encoding: .utf8) {
                logger?.error("Did fail to parse subscription data: \(responseString)")
            } else {
                logger?.error("Did fail to parse subscription data")
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
            .first(where: { $1.remoteId == remoteId })
        {
            logger?.debug("Did receive update for subscription: \(remoteId)")

            completionQueue.async {
                try? subscription.handle(data: data)
            }
        } else {
            logger?.warning("No handler for subscription: \(remoteId)")
            if unknownResponsesByRemoteId[remoteId] == nil {
                unknownResponsesByRemoteId[remoteId] = []
            }

            unknownResponsesByRemoteId[remoteId]?.append(data)
        }
    }

    func completeRequestForRemoteId(_ identifier: UInt16, error: Error) {
        if cancelGuardedRequest(identifier) == .requestNotSent {
            if let request = inProgressRequests.removeValue(forKey: identifier) {
                notify(requests: [request], error: JSONRPCEngineError.requestNotSent)
            }
            processSubscriptionError(identifier, error: JSONRPCEngineError.requestNotSent, shouldUnsubscribe: true)
            return
        }
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
            for request in requests {
                request.responseHandler?.handle(error: error)
            }
        }
    }

    func scheduleReconnectionOrDisconnect(_ attempt: Int, after error: Error? = nil) {
        cancelPendingGuardedRequests()
        if reachabilityManager?.isReachable == false {
            state = .notReachable
        } else if let reconnectionStrategy = reconnectionStrategy,
                  let nextDelay = reconnectionStrategy.reconnectAfter(attempt: attempt - 1)
        {
            state = .waitingReconnection(attempt: attempt)

            logger?.debug("Schedule reconnection with attempt \(attempt) and delay \(nextDelay)")

            reconnectionScheduler.notifyAfter(nextDelay)
        } else {
            state = .notConnected

            // notify pendings about error because there is no chance to reconnect

            let requests = pendingRequests
            pendingRequests = []

            let requestError = error ?? JSONRPCEngineError.unknownError
            notify(requests: requests, error: requestError)
        }
    }

    func schedulePingIfNeeded() {
        guard pingInterval > 0.0, case .connected = state else {
            return
        }

        logger?.debug("Schedule socket ping")

        pingScheduler.notifyAfter(pingInterval)
    }

    func sendPing() {
        guard case .connected = state else {
            logger?.warning("Tried to send ping but not connected")
            return
        }

        logger?.debug("Sending socket ping")

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
            logger?.error("Did receive ping error: \(error)")
        }
    }

    func handlePing(result: Result<Health, Error>) {
        switch result {
        case let .success(health):
            if health.isSyncing {
                logger?.warning("Node is not healthy")
            }
        case let .failure(error):
            logger?.error("Health check error: \(error)")
        }
    }

    func startConnecting(_ attempt: Int) {
        logger?.debug("Start connecting with attempt: \(attempt)")

        if reachabilityManager?.isReachable == true {
            state = .connecting(attempt: attempt)
        } else {
            state = .notReachable
        }

        connection.connect()
    }

    private func handleNodeNotHealthy() {
        connection.disconnect()
        scheduleReconnectionOrDisconnect(NetworkConstants.websocketReconnectAttemptsLimit + 1)
    }

    private func processUnsubscription(_ identifier: UInt16) throws {
        mutex.lock()
        let current = subscriptions[identifier]
        mutex.unlock()
        guard let subscription = current else { return }

        let requestInfo = try jsonDecoder.decode(
            JSONRPCInfo<[[Data]]>.self,
            from: subscription.requestData
        )

        _ = try callMethod(
            RPCMethod.stateUnsubscribe,
            params: requestInfo.params,
            options: JSONRPCOptions(resendOnReconnect: false)
        ) { [weak self] (result: Result<Data, Error>) in
            guard case .success = result, let self = self else { return }
            self.mutex.lock()
            defer { self.mutex.unlock() }
            if self.subscriptions[identifier] === subscription {
                self.subscriptions.removeValue(forKey: identifier)
            }
        }
    }
}


private final class RPCWriteAuthorization: WebSocketWriteAuthorizing {
    private let application: JSONRPCWriteAuthorizing
    init(_ application: JSONRPCWriteAuthorizing) { self.application = application }
    func authorize(_ handoff: () throws -> Void) throws { try application.authorize(handoff) }
}
