import Foundation

/// A message a peer published to a topic this client listens to.
public struct RelayMessage: Hashable, Sendable {
    public let topic: String
    public let message: String
    /// Milliseconds since 1970, as the relay reports it.
    public let publishedAt: Int64
    public let tag: Int?
    public let attestation: String?

    init(topic: String, message: String, publishedAt: Int64, tag: Int?, attestation: String?) {
        self.topic = topic
        self.message = message
        self.publishedAt = publishedAt
        self.tag = tag
        self.attestation = attestation
    }

    init?(json: JSONValue, now: Date) {
        guard
            let topic = json["topic"]?.stringValue, Hex.isKey(topic),
            let message = json["message"]?.stringValue, !message.isEmpty
        else {
            return nil
        }
        self.topic = topic
        self.message = message
        publishedAt = json["publishedAt"]?.int64Value ?? Int64(now.timeIntervalSince1970 * 1000)
        tag = json["tag"]?.int64Value.map { Int(truncatingIfNeeded: $0) }
        attestation = json["attestation"]?.stringValue
    }
}

public enum RelayError: Error, Equatable {
    case closed
    case connectionFailed(String)
    case timeout(method: String)
    case rejected(code: Int, message: String)
}

/// The WalletConnect relay over a WebSocket: subscribe to topics, publish to them, receive what peers published and
/// fetch what the relay held while no socket listened. The relay only ever sees encrypted envelopes.
actor RelayConnection {
    struct Configuration: Sendable {
        var url: URL
        var projectId: String
        var userAgent: String
        /// Sent as `bundleId`, which the relay checks against the project's allowed iOS apps.
        var bundleId: String?
        var requestTimeout: TimeInterval = 15
        var keepAliveInterval: TimeInterval = 30
        var reconnectMinimum: TimeInterval = 1
        var reconnectMaximum: TimeInterval = 30
    }

    typealias TokenProvider = @Sendable (_ audience: String) async throws -> String

    private static let maxFrameBytes = 2_000_000
    private static let subscribeBatch = 100
    private static let maxFetchRounds = 25

    nonisolated let messages: AsyncStream<RelayMessage>
    private nonisolated let messageContinuation: AsyncStream<RelayMessage>.Continuation

    private let configuration: Configuration
    private let transportFactory: RelayTransportFactory
    private let tokenProvider: TokenProvider
    private let clock: WalletConnectClock
    private let logger: WalletConnectLogging
    private let identifiers = RPCIdentifierGenerator()

    private struct Pending {
        let continuation: CheckedContinuation<JSONValue, Error>
        let method: String
        let generation: Int
    }

    private var socket: RelayTransport?
    private var socketGeneration = 0
    private var generationCounter = 0
    private var opening: Task<RelayTransport, Error>?
    private var openWaiter: (generation: Int, continuation: CheckedContinuation<Void, Error>)?
    private var pending: [Int64: Pending] = [:]
    /// Topics this client wants to hear, and the relay's subscription id on the current socket.
    private var topics: [String: String?] = [:]
    private var reconnectTask: Task<Void, Never>?
    private var keepAliveTask: Task<Void, Never>?
    private var reconnectDelay: TimeInterval
    private var closed = false

    init(
        configuration: Configuration,
        transportFactory: RelayTransportFactory,
        tokenProvider: @escaping TokenProvider,
        clock: WalletConnectClock,
        logger: WalletConnectLogging
    ) {
        self.configuration = configuration
        self.transportFactory = transportFactory
        self.tokenProvider = tokenProvider
        self.clock = clock
        self.logger = logger
        reconnectDelay = configuration.reconnectMinimum
        var continuation: AsyncStream<RelayMessage>.Continuation!
        messages = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        messageContinuation = continuation
    }

    var isOpen: Bool {
        socket != nil
    }

    var subscribedTopics: [String] {
        Array(topics.keys)
    }

    // MARK: - Topics

    /// Subscribes and then fetches what the relay holds for the topics, so a message sent before is not missed.
    func subscribe(_ newTopics: [String]) async throws {
        let added = newTopics.orderedUnique().filter { Hex.isKey($0) && topics[$0] == nil }
        guard !added.isEmpty else {
            return
        }
        closed = false
        for topic in added {
            topics[topic] = .some(nil)
        }

        let transport = try await open()
        let unsubscribed = added.filter { topics[$0] == .some(nil) }
        if !unsubscribed.isEmpty {
            try await subscribe(unsubscribed, on: transport)
        }

        // The subscription holds; anything a failed fetch missed comes with the next connection's fetch.
        do {
            try await fetchMessages(added)
        } catch {
            logger.warning("WalletConnect relay fetch failed: \(error)")
        }
    }

    func unsubscribe(_ topic: String) async {
        guard let entry = topics[topic] else {
            return
        }
        topics[topic] = nil

        if topics.isEmpty {
            close()
            return
        }

        if let id = entry, let transport = socket {
            _ = try? await send("irn_unsubscribe", params: .object(["topic": .string(topic), "id": .string(id)]), on: transport)
        }
    }

    func publish(topic: String, message: String, ttl: Int, tag: Int, prompt: Bool) async throws {
        var params: [String: JSONValue] = [
            "topic": .string(topic),
            "message": .string(message),
            "ttl": .int(ttl),
            "tag": .int(tag)
        ]
        if prompt {
            params["prompt"] = .bool(true)
        }

        defer {
            // A last message, such as a disconnection, does not leave a connection open with nothing to hear.
            if topics.isEmpty {
                close()
            }
        }

        let transport = try await open()
        _ = try await send("irn_publish", params: .object(params), on: transport)
    }

    /// Delivers what the relay holds for the topics, oldest first.
    func fetchMessages(_ fetchTopics: [String]) async throws {
        var start = 0
        while start < fetchTopics.count {
            let batch = Array(fetchTopics[start ..< min(start + Self.subscribeBatch, fetchTopics.count)])
            start += Self.subscribeBatch

            for _ in 0 ..< Self.maxFetchRounds {
                // Fetching never reopens a connection that was closed meanwhile, for example for the background.
                guard let transport = socket else {
                    throw RelayError.closed
                }
                let result = try await send(
                    "irn_batchFetchMessages",
                    params: .object(["topics": .array(batch.map(JSONValue.string))]),
                    on: transport
                )
                let now = clock.now()
                let delivered = (result["messages"]?.arrayValue ?? [])
                    .compactMap { RelayMessage(json: $0, now: now) }
                    .filter { topics[$0.topic] != nil }
                    .sorted { $0.publishedAt < $1.publishedAt }
                for message in delivered {
                    messageContinuation.yield(message)
                }
                guard result["hasMore"]?.boolValue == true else {
                    break
                }
            }
        }
    }

    // MARK: - Lifecycle

    /// Closes the connection and stops reconnecting until the next subscription or `resume()`.
    func close() {
        closed = true
        reconnectTask?.cancel()
        reconnectTask = nil
        keepAliveTask?.cancel()
        keepAliveTask = nil
        opening?.cancel()
        opening = nil
        if let waiter = openWaiter {
            openWaiter = nil
            waiter.continuation.resume(throwing: RelayError.closed)
        }
        let current = socket
        socket = nil
        resetSubscriptionIds()
        failPending(RelayError.closed)
        current?.close()
    }

    /// Reconnects after `close()` when there is anything to hear.
    func resume() async {
        closed = false
        guard !topics.isEmpty, socket == nil else {
            return
        }
        do {
            _ = try await open()
        } catch {
            logger.warning("WalletConnect relay is unavailable: \(error)")
            scheduleReconnect()
        }
    }

    /// Ends this connection for good: no further messages are delivered.
    func shutdown() {
        close()
        topics.removeAll()
        messageContinuation.finish()
    }

    // MARK: - Connection

    /// The connection, opened if needed. Something to send or subscribe reopens a closed connection.
    private func open() async throws -> RelayTransport {
        closed = false
        if let socket {
            return socket
        }
        if let opening {
            return try await opening.value
        }

        reconnectTask?.cancel()
        reconnectTask = nil
        let task = Task { try await self.connect() }
        opening = task
        do {
            let transport = try await task.value
            if opening == task {
                opening = nil
            }
            return transport
        } catch {
            if opening == task {
                opening = nil
            }
            throw error
        }
    }

    private func connect() async throws -> RelayTransport {
        let token = try await tokenProvider(configuration.url.absoluteString)
        var components = URLComponents(url: configuration.url, resolvingAgainstBaseURL: false)
        var query = components?.queryItems ?? []
        query.append(URLQueryItem(name: "auth", value: token))
        query.append(URLQueryItem(name: "projectId", value: configuration.projectId))
        query.append(URLQueryItem(name: "ua", value: configuration.userAgent))
        if let bundleId = configuration.bundleId {
            query.append(URLQueryItem(name: "bundleId", value: bundleId))
        }
        components?.queryItems = query
        guard let url = components?.url else {
            throw RelayError.connectionFailed("relay URL")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = configuration.requestTimeout * 2
        request.setValue(configuration.userAgent, forHTTPHeaderField: "User-Agent")

        generationCounter += 1
        let generation = generationCounter
        let transport = transportFactory.makeTransport()
        let events = transport.events
        Task { [weak self] in
            for await event in events {
                await self?.handle(event, transport: transport, generation: generation)
            }
            await self?.handle(.closed(code: nil, reason: "stream ended"), transport: transport, generation: generation)
        }

        do {
            try await waitForOpen(transport: transport, request: request, generation: generation)
        } catch {
            transport.close()
            if !closed {
                scheduleReconnect()
            }
            throw error
        }

        guard !closed else {
            transport.close()
            throw RelayError.closed
        }

        socket = transport
        socketGeneration = generation
        reconnectDelay = configuration.reconnectMinimum
        resetSubscriptionIds()
        startKeepAlive(transport: transport, generation: generation)

        let wanted = Array(topics.keys)
        if !wanted.isEmpty {
            do {
                try await subscribe(wanted, on: transport)
            } catch {
                // A socket that could not subscribe hears nothing; replace it.
                drop(transport: transport, generation: generation)
                throw error
            }
            // Messages held while no socket listened, including while the app was in the background.
            Task { [weak self] in
                do {
                    try await self?.fetchMessages(wanted)
                } catch {
                    await self?.logFetchFailure(error)
                }
            }
        }

        return transport
    }

    private func logFetchFailure(_ error: Error) {
        logger.warning("WalletConnect relay fetch failed: \(error)")
    }

    private func waitForOpen(transport: RelayTransport, request: URLRequest, generation: Int) async throws {
        let timeout = configuration.requestTimeout
        let sleep = clock.sleep
        let timer = Task { [weak self] in
            do {
                try await sleep(timeout)
            } catch {
                return
            }
            await self?.failOpen(generation: generation, error: RelayError.timeout(method: "connect"))
        }
        defer { timer.cancel() }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            openWaiter = (generation, continuation)
            transport.connect(request: request)
        }
    }

    private func failOpen(generation: Int, error: Error) {
        guard let waiter = openWaiter, waiter.generation == generation else {
            return
        }
        openWaiter = nil
        waiter.continuation.resume(throwing: error)
    }

    private func handle(_ event: RelayTransportEvent, transport: RelayTransport, generation: Int) async {
        switch event {
        case .opened:
            if let waiter = openWaiter, waiter.generation == generation {
                openWaiter = nil
                waiter.continuation.resume()
            }
        case let .text(text):
            guard generation == socketGeneration, socket === transport else {
                return
            }
            await handleFrame(text, transport: transport)
        case let .closed(code, reason):
            failOpen(generation: generation, error: RelayError.connectionFailed("closed \(code.map(String.init) ?? "-") \(reason ?? "")"))
            if generation == socketGeneration, socket === transport {
                logger.info("WalletConnect relay closed the connection (\(code.map(String.init) ?? "no code"))")
                onClosed(generation: generation)
            }
        case let .failed(reason):
            failOpen(generation: generation, error: RelayError.connectionFailed(reason))
            if generation == socketGeneration, socket === transport {
                logger.info("WalletConnect relay connection failed")
                onClosed(generation: generation)
            }
        }
    }

    private func handleFrame(_ text: String, transport: RelayTransport) async {
        guard text.utf8.count <= Self.maxFrameBytes, let json = try? JSONParser.parse(text) else {
            return
        }
        guard let message = RPCMessage(json: json) else {
            return
        }

        switch message {
        case let .request(id, method, params):
            guard method == "irn_subscription" else {
                return
            }
            // Acknowledge first: the relay keeps redelivering an unacknowledged message.
            let ack = RPCMessage.response(id: id, result: .response(AnyCodable(json: .bool(true)))).text
            try? await transport.send(text: ack)
            if let data = params["data"], let delivered = RelayMessage(json: data, now: clock.now()),
               topics[delivered.topic] != nil {
                messageContinuation.yield(delivered)
            }
        case let .response(id, result):
            guard let entry = pending.removeValue(forKey: id) else {
                return
            }
            switch result {
            case let .response(value):
                entry.continuation.resume(returning: value.value)
            case let .error(error):
                entry.continuation.resume(throwing: RelayError.rejected(code: error.code, message: error.message))
            }
        }
    }

    private func send(_ method: String, params: JSONValue, on transport: RelayTransport) async throws -> JSONValue {
        let id = identifiers.next(now: clock.now())
        let text = RPCMessage.request(id: id, method: method, params: params).text
        let generation = socketGeneration
        let timeout = configuration.requestTimeout
        let sleep = clock.sleep

        let timer = Task { [weak self] in
            do {
                try await sleep(timeout)
            } catch {
                return
            }
            await self?.timeOut(id: id, transport: transport, generation: generation)
        }
        defer { timer.cancel() }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<JSONValue, Error>) in
            pending[id] = Pending(continuation: continuation, method: method, generation: generation)
            Task { [weak self] in
                do {
                    try await transport.send(text: text)
                } catch {
                    await self?.fail(id: id, error: error)
                }
            }
        }
    }

    private func fail(id: Int64, error: Error) {
        pending.removeValue(forKey: id)?.continuation.resume(throwing: error)
    }

    private func timeOut(id: Int64, transport: RelayTransport, generation: Int) {
        guard let entry = pending.removeValue(forKey: id) else {
            return
        }
        entry.continuation.resume(throwing: RelayError.timeout(method: entry.method))
        // A socket that stopped answering is replaced.
        if socket === transport, socketGeneration == generation {
            drop(transport: transport, generation: generation)
        }
    }

    private func subscribe(_ subscribeTopics: [String], on transport: RelayTransport) async throws {
        var start = 0
        while start < subscribeTopics.count {
            let batch = Array(subscribeTopics[start ..< min(start + Self.subscribeBatch, subscribeTopics.count)])
            start += Self.subscribeBatch

            let ids: [JSONValue]
            if batch.count == 1 {
                ids = [try await send("irn_subscribe", params: .object(["topic": .string(batch[0])]), on: transport)]
            } else {
                let result = try await send(
                    "irn_batchSubscribe",
                    params: .object(["topics": .array(batch.map(JSONValue.string))]),
                    on: transport
                )
                ids = result.arrayValue ?? []
            }

            for (index, topic) in batch.enumerated() where topics[topic] != nil {
                topics[topic] = .some(ids.indices.contains(index) ? ids[index].stringValue ?? "" : "")
            }
        }
    }

    private func resetSubscriptionIds() {
        for topic in topics.keys {
            topics[topic] = .some(nil)
        }
    }

    private func failPending(_ error: Error) {
        let entries = pending
        pending.removeAll()
        for entry in entries.values {
            entry.continuation.resume(throwing: error)
        }
    }

    private func drop(transport: RelayTransport, generation: Int) {
        transport.close()
        onClosed(generation: generation)
    }

    private func onClosed(generation: Int) {
        guard generation == socketGeneration, socket != nil else {
            return
        }
        socket = nil
        keepAliveTask?.cancel()
        keepAliveTask = nil
        resetSubscriptionIds()
        let failed = pending.filter { $0.value.generation == generation }
        for (id, entry) in failed {
            pending.removeValue(forKey: id)
            entry.continuation.resume(throwing: RelayError.connectionFailed("relay connection closed"))
        }
        scheduleReconnect()
    }

    private func scheduleReconnect() {
        guard !closed, !topics.isEmpty, reconnectTask == nil, socket == nil else {
            return
        }
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, configuration.reconnectMaximum)
        let sleep = clock.sleep
        reconnectTask = Task { [weak self] in
            do {
                try await sleep(delay)
            } catch {
                return
            }
            await self?.reconnectNow()
        }
    }

    private func reconnectNow() async {
        reconnectTask = nil
        guard !closed, !topics.isEmpty, socket == nil else {
            return
        }
        do {
            _ = try await open()
        } catch {
            logger.warning("WalletConnect relay reconnect failed: \(error)")
        }
    }

    private func startKeepAlive(transport: RelayTransport, generation: Int) {
        keepAliveTask?.cancel()
        let interval = configuration.keepAliveInterval
        let sleep = clock.sleep
        keepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await sleep(interval)
                } catch {
                    return
                }
                guard let before = await self?.pongCount else {
                    return
                }
                // A ping the socket never answers must not hold this loop, so it runs on its own.
                Task { [weak self] in
                    if (try? await transport.sendPing()) != nil {
                        await self?.recordPong()
                    }
                }
                do {
                    try await sleep(interval / 3)
                } catch {
                    return
                }
                guard let after = await self?.pongCount else {
                    return
                }
                if after == before {
                    await self?.keepAliveFailed(transport: transport, generation: generation)
                    return
                }
            }
        }
    }

    private var pongCount = 0

    private func recordPong() {
        pongCount += 1
    }

    private func keepAliveFailed(transport: RelayTransport, generation: Int) {
        guard socket === transport, socketGeneration == generation else {
            return
        }
        logger.info("WalletConnect relay stopped answering pings")
        drop(transport: transport, generation: generation)
    }
}
