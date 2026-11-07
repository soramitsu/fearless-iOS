import Combine
import CryptoKit
import Foundation

/// A WalletConnect v2 Sign client in the wallet role: dApps pair with Fearless, propose sessions, and send requests
/// that the person approves or refuses. One relay connection carries every pairing and session.
public actor WalletConnectClient {
    public struct Configuration: Sendable {
        public static let defaultRelayURL = URL(string: "wss://relay.walletconnect.org")!

        public var projectId: String
        public var relayURL: URL
        public var metadata: AppMetadata
        /// Sent to the relay, which checks it against the project's allowed iOS apps.
        public var bundleId: String?
        public var userAgent: String
        /// Whether proposals and requests are checked with the Verify service.
        public var verifiesOrigins: Bool
        public var requestTimeout: TimeInterval
        public var keepAliveInterval: TimeInterval

        public init(
            projectId: String,
            relayURL: URL = Configuration.defaultRelayURL,
            metadata: AppMetadata,
            bundleId: String?,
            userAgent: String,
            verifiesOrigins: Bool = true,
            requestTimeout: TimeInterval = 15,
            keepAliveInterval: TimeInterval = 30
        ) {
            self.projectId = projectId
            self.relayURL = relayURL
            self.metadata = metadata
            self.bundleId = bundleId
            self.userAgent = userAgent
            self.verifiesOrigins = verifiesOrigins
            self.requestTimeout = requestTimeout
            self.keepAliveInterval = keepAliveInterval
        }
    }

    public enum Event: Sendable {
        case sessionProposal(Session.Proposal, VerifyContext)
        case sessionRequest(Request, VerifyContext)
        case sessionsChanged([Session])
        case sessionDeleted(topic: String)
        case proposalExpired(id: Int64)
        case requestExpired(id: Int64, topic: String)
        case sessionPinged(topic: String)
    }

    public enum ClientError: Error, Equatable {
        case notStarted
        case pairingAlreadyActive
        case pairingExpired
        case proposalNotFound
        case proposalExpired
        case invalidNamespaces
        case sessionNotFound
        case noMatchingKey
        case peerError(code: Int, message: String)
        case timeout
        case closed
    }

    static let maxPendingProposals = 20
    static let maxPendingRequests = 200
    static let maxSeen = 1000
    static let maxForgotten = 500
    static let maxSweepDelay: TimeInterval = 3600

    let configuration: Configuration
    let stateStore: WalletConnectStateStore
    let secretStore: WalletConnectSecretStore
    let legacyStorage: LegacyWalletConnectStorage?
    let clock: WalletConnectClock
    let logger: WalletConnectLogging
    let verify: VerifyClient
    let identifiers = RPCIdentifierGenerator()
    let relay: RelayConnection
    private let seedBox: SeedBox

    var state = WalletConnectState()
    var secrets = WalletConnectSecrets(clientSeed: "", keys: [:])
    var started = false
    var inboundTask: Task<Void, Never>?
    var sweepTask: Task<Void, Never>?
    var waiting: [Int64: Waiter] = [:]

    struct Waiter {
        let topic: String
        let promise: ResponsePromise
    }

    private nonisolated let hub = EventHub()
    private nonisolated let sessionSnapshot = SessionSnapshot()

    /// Everything the client reports, in order.
    public nonisolated var events: AnyPublisher<Event, Never> {
        hub.subject.eraseToAnyPublisher()
    }

    /// The sessions as of the last change, without waiting for the client.
    public nonisolated var currentSessions: [Session] {
        sessionSnapshot.sessions
    }

    public init(
        configuration: Configuration,
        stateStore: WalletConnectStateStore,
        secretStore: WalletConnectSecretStore,
        legacyStorage: LegacyWalletConnectStorage? = nil,
        transportFactory: RelayTransportFactory = URLSessionRelayTransportFactory(),
        verify: VerifyClient? = nil,
        clock: WalletConnectClock = .system,
        logger: WalletConnectLogging = SilentWalletConnectLogger()
    ) {
        self.configuration = configuration
        self.stateStore = stateStore
        self.secretStore = secretStore
        self.legacyStorage = legacyStorage
        self.clock = clock
        self.logger = logger
        self.verify = verify ?? VerifyClient(now: clock.now)

        let relayConfiguration = RelayConnection.Configuration(
            url: configuration.relayURL,
            projectId: configuration.projectId,
            userAgent: configuration.userAgent,
            bundleId: configuration.bundleId,
            requestTimeout: configuration.requestTimeout,
            keepAliveInterval: configuration.keepAliveInterval
        )
        let box = SeedBox()
        relay = RelayConnection(
            configuration: relayConfiguration,
            transportFactory: transportFactory,
            tokenProvider: { audience in
                guard let seed = box.seed else {
                    throw ClientError.notStarted
                }
                return try RelayAuth.token(
                    seed: seed,
                    audience: audience,
                    subject: Hex.encode(try WalletConnectCrypto.randomKey()),
                    issuedAt: clock.nowSeconds
                )
            },
            clock: clock,
            logger: logger
        )
        seedBox = box
    }

    // MARK: - Lifecycle

    /// Loads the stored sessions, carries over what earlier SDKs saved, and connects to the relay in the
    /// background. Calling it again after `stop()` reconnects.
    public func start() async throws {
        guard !started else {
            await relay.resume()
            return
        }

        try load()
        started = true
        publishSessions()

        let messages = relay.messages
        inboundTask = Task { [weak self] in
            for await message in messages {
                await self?.process(message)
            }
        }

        await sweep()
        let topics = state.liveTopics
        if !topics.isEmpty {
            let relay = self.relay
            let logger = self.logger
            Task {
                do {
                    try await relay.subscribe(topics)
                } catch {
                    logger.warning("WalletConnect relay is unavailable: \(error)")
                }
            }
        }
    }

    /// Disconnects from the relay and stops the timers. Sessions stay; `start()` or `resume()` reconnects.
    public func stop() async {
        sweepTask?.cancel()
        sweepTask = nil
        await relay.close()
        failWaiting(ClientError.closed)
    }

    /// Reconnects after the app returns to the foreground, and fetches what the relay held meanwhile.
    public func resume() async {
        guard started else {
            return
        }
        await relay.resume()
        scheduleSweep()
    }

    /// Closes the relay connection while the app is in the background. The relay holds messages meanwhile.
    public func suspend() async {
        await relay.close()
    }

    /// The relay identity, `did:key:...`.
    public func clientId() throws -> String {
        guard let seed = seedBox.seed else {
            throw ClientError.notStarted
        }
        return try RelayAuth.clientId(seed: seed)
    }

    public func pendingProposals() -> [Session.Proposal] {
        state.proposals.map(\.publicProposal)
    }

    public func sessions() -> [Session] {
        state.sessions.map(\.publicSession)
    }

    /// Whether the dApp confirmed a session's settlement.
    public func isAcknowledged(topic: String) -> Bool {
        state.sessions.first { $0.topic == topic }?.acknowledged == true
    }

    func storedSession(topic: String) -> StoredSession? {
        state.sessions.first { $0.topic == topic }
    }

    func storedState() -> WalletConnectState {
        state
    }

    func storedSecrets() -> WalletConnectSecrets {
        secrets
    }

    // MARK: - Storage

    func load() throws {
        let decoder = JSONDecoder()
        let storedState = try stateStore.loadState().flatMap { try? decoder.decode(WalletConnectState.self, from: $0) }
        let storedSecrets = try secretStore.loadSecrets().flatMap { try? decoder.decode(WalletConnectSecrets.self, from: $0) }

        var state = storedState ?? WalletConnectState()
        var secrets = storedSecrets ?? WalletConnectSecrets(clientSeed: "", keys: [:])
        var secretsChanged = storedSecrets == nil

        if let legacyStorage {
            let known = Set(state.liveTopics + state.forgottenTopics)
            let imported = LegacyWalletConnectImporter(storage: legacyStorage).read(now: clock.now(), skipping: known)
            if !imported.sessions.isEmpty || !imported.pairings.isEmpty {
                for (topic, key) in imported.keys {
                    secrets.keys[topic] = Hex.encode(key)
                }
                state.sessions.append(contentsOf: imported.sessions)
                state.pairings.append(contentsOf: imported.pairings)
                secretsChanged = true
            }
            // The same relay identity, so the relay treats this client as the one that subscribed.
            let adoptsIdentity = storedSecrets == nil && imported.clientSeed != nil
            if adoptsIdentity, let seed = imported.clientSeed {
                secrets.clientSeed = Hex.encode(seed)
            }
            if storedState == nil || !imported.sessions.isEmpty || !imported.pairings.isEmpty {
                state.legacyImport = LegacyImportSummary(
                    at: clock.nowSeconds,
                    sessions: imported.sessions.count,
                    pairings: imported.pairings.count,
                    clientIdentity: adoptsIdentity
                )
                logger.info(
                    "WalletConnect carried over \(imported.sessions.count) sessions and \(imported.pairings.count) pairings"
                        + " from earlier records (\(imported.skippedSessions) expired or unreadable sessions left)"
                )
            }
        }

        if Hex.decodeKey(secrets.clientSeed) == nil {
            secrets.clientSeed = Hex.encode(try WalletConnectCrypto.randomKey())
            secretsChanged = true
        }

        // A session or pairing without its key cannot be used; a key nothing uses is not kept.
        let keyed = { (topic: String) in Hex.decodeKey(secrets.keys[topic] ?? "") != nil }
        let droppedSessions = state.sessions.filter { !keyed($0.topic) }.count
        state.sessions.removeAll { !keyed($0.topic) }
        state.pairings.removeAll { !keyed($0.topic) }
        state.proposals.removeAll { proposal in !state.pairings.contains { $0.topic == proposal.pairingTopic } }
        state.requests.removeAll { request in !state.sessions.contains { $0.topic == request.topic } }
        state.settlements = state.settlements.filter { topic, _ in state.sessions.contains { $0.topic == topic } }
        let live = Set(state.liveTopics)
        let unusedKeys = secrets.keys.keys.filter { !live.contains($0) }
        if !unusedKeys.isEmpty {
            for topic in unusedKeys {
                secrets.keys[topic] = nil
            }
            secretsChanged = true
        }
        if droppedSessions > 0 {
            logger.warning("WalletConnect dropped \(droppedSessions) sessions whose keys are missing")
        }

        self.state = state
        self.secrets = secrets
        seedBox.seed = Hex.decodeKey(secrets.clientSeed)

        // Keys first: a record never names a session whose key was not written.
        if secretsChanged {
            try saveSecrets()
        }
        try saveState()
    }

    func saveState() throws {
        state.seen = Array(state.seen.suffix(Self.maxSeen))
        state.forgottenTopics = Array(state.forgottenTopics.suffix(Self.maxForgotten))
        try stateStore.saveState(WalletConnectCoding.encoder().encode(state))
    }

    func saveSecrets() throws {
        try secretStore.saveSecrets(WalletConnectCoding.encoder().encode(secrets))
    }

    func persist() {
        do {
            try saveState()
        } catch {
            logger.error("WalletConnect could not save its record: \(error)")
        }
    }

    func key(for topic: String) -> Data? {
        secrets.keys[topic].flatMap(Hex.decodeKey)
    }

    func publishSessions() {
        let sessions = state.sessions.map(\.publicSession)
        sessionSnapshot.sessions = sessions
        hub.subject.send(.sessionsChanged(sessions))
    }

    func emit(_ event: Event) {
        hub.subject.send(event)
    }

    // MARK: - Sending

    func publish(_ message: RPCMessage, on topic: String, options: PublishOptions) async throws {
        guard let key = key(for: topic) else {
            throw ClientError.noMatchingKey
        }
        let envelope = try WalletConnectCrypto.seal(Data(message.text.utf8), symmetricKey: key)
        markSeen(WalletConnectCrypto.messageHash(envelope))
        try await relay.publish(
            topic: topic,
            message: envelope,
            ttl: options.ttl,
            tag: options.tag,
            prompt: options.prompt
        )
    }

    /// An answer that may fail without consequence: the peer asks again or gives up.
    func reply(_ message: RPCMessage, on topic: String, options: PublishOptions) async {
        do {
            try await publish(message, on: topic, options: options)
        } catch {
            logger.warning("WalletConnect answer was not sent: \(error)")
        }
    }

    /// Registers a wait for the peer's answer to `id` before the request is sent, so the answer cannot arrive first.
    func expectResponse(id: Int64, topic: String, timeout: TimeInterval) -> ResponsePromise {
        let promise = ResponsePromise()
        waiting[id] = Waiter(topic: topic, promise: promise)
        let sleep = clock.sleep
        Task { [weak self] in
            do {
                try await sleep(timeout)
            } catch {
                return
            }
            await self?.failWaiter(id: id, error: ClientError.timeout)
        }
        return promise
    }

    func resolveWaiter(id: Int64, topic: String, result: RPCResult) -> Bool {
        guard let waiter = waiting[id], waiter.topic == topic else {
            return false
        }
        waiting[id] = nil
        waiter.promise.resolve(.success(result))
        return true
    }

    func failWaiter(id: Int64, error: Error) {
        waiting.removeValue(forKey: id)?.promise.resolve(.failure(error))
    }

    func failWaiting(_ error: Error, topic: String? = nil) {
        for (id, waiter) in waiting where topic == nil || waiter.topic == topic {
            waiting.removeValue(forKey: id)
            waiter.promise.resolve(.failure(error))
        }
    }

    func markSeen(_ hash: String) {
        state.seen.append(SeenMessage(hash: hash, at: clock.nowSeconds))
        if state.seen.count > Self.maxSeen * 2 {
            state.seen.removeFirst(state.seen.count - Self.maxSeen)
        }
    }

    func hasSeen(_ hash: String) -> Bool {
        state.seen.contains { $0.hash == hash }
    }
}

/// A peer's answer to one request, waited for once.
final class ResponsePromise: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<RPCResult, Error>?
    private var continuation: CheckedContinuation<RPCResult, Error>?

    func resolve(_ value: Result<RPCResult, Error>) {
        lock.lock()
        guard result == nil else {
            lock.unlock()
            return
        }
        result = value
        let waiting = continuation
        continuation = nil
        lock.unlock()
        waiting?.resume(with: value)
    }

    func value() async throws -> RPCResult {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result {
                lock.unlock()
                continuation.resume(with: result)
            } else {
                self.continuation = continuation
                lock.unlock()
            }
        }
    }
}

/// Sends events from the client to subscribers on any thread.
private final class EventHub: @unchecked Sendable {
    let subject = PassthroughSubject<WalletConnectClient.Event, Never>()
}

private final class SessionSnapshot: @unchecked Sendable {
    private let lock = NSLock()
    private var value: [Session] = []

    var sessions: [Session] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}

/// The relay identity, readable by the token provider without waiting for the client.
private final class SeedBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Data?

    var seed: Data? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}
