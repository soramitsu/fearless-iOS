import Foundation
@testable import FearlessWalletConnect

/// An in-memory WalletConnect relay that follows the live relay's delivery rules: a message published to a topic
/// nobody else listens to is held and given to the first client that subscribes, once; each delivery is an
/// `irn_subscription` the client acknowledges; a publisher does not get its own message back.
final class FakeRelay: RelayTransportFactory, @unchecked Sendable {
    struct Published: Equatable {
        let topic: String
        let message: String
        let ttl: Int
        let tag: Int
        let prompt: Bool
        let connection: Int
    }

    private struct Held {
        let topic: String
        let message: String
        let publishedAt: Int64
        let tag: Int
        var attestation: String?
    }

    private let lock = NSLock()
    /// The relay handles one frame at a time, in the order clients sent them.
    let queue = DispatchQueue(label: "FakeRelay")
    private var connections: [Int: FakeRelayTransport] = [:]
    private var subscriptions: [String: Set<Int>] = [:]
    private var held: [String: [Held]] = [:]
    private var nextConnection = 0
    private var deliveriesAwaitingAck: Set<Int64> = []
    private(set) var published: [Published] = []
    private(set) var urls: [URL] = []
    private(set) var acknowledged = 0
    private(set) var delivered = 0
    var refusesConnections = false

    func makeTransport() -> RelayTransport {
        lock.lock()
        nextConnection += 1
        let transport = FakeRelayTransport(relay: self, connection: nextConnection)
        lock.unlock()
        return transport
    }

    // MARK: - Test controls

    func heldCount(for topic: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return held[topic]?.count ?? 0
    }

    func publishedMessages(on topic: String) -> [Published] {
        lock.lock()
        defer { lock.unlock() }
        return published.filter { $0.topic == topic }
    }

    var allPublished: [Published] {
        lock.lock()
        defer { lock.unlock() }
        return published
    }

    var unacknowledgedDeliveries: Int {
        lock.lock()
        defer { lock.unlock() }
        return deliveriesAwaitingAck.count
    }

    var openConnections: Int {
        lock.lock()
        defer { lock.unlock() }
        return connections.count
    }

    func isSubscribed(_ topic: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !(subscriptions[topic] ?? []).isEmpty
    }

    func subscriberCount(_ topic: String) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return subscriptions[topic]?.count ?? 0
    }

    /// The connection URLs of the clients that sent this user agent.
    func urls(userAgent: String) -> [URL] {
        lock.lock()
        defer { lock.unlock() }
        return urls.filter { url in
            URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.contains { $0.name == "ua" && $0.value == userAgent } == true
        }
    }

    /// Publishes as some other relay client would.
    func inject(topic: String, message: String, tag: Int = 0, attestation: String? = nil) {
        queue.sync {
            publish(topic: topic, message: message, ttl: 300, tag: tag, prompt: false, from: -1, attestation: attestation)
        }
    }

    /// Attaches the Verify attestation the relay passes along with the messages it holds for a topic.
    func attest(topic: String, attestation: String) {
        lock.lock()
        if var entries = held[topic] {
            for index in entries.indices {
                entries[index].attestation = attestation
            }
            held[topic] = entries
        }
        lock.unlock()
    }

    /// Drops every connection, as the relay does when it restarts.
    func disconnectAll() {
        lock.lock()
        let all = Array(connections.values)
        connections.removeAll()
        subscriptions.removeAll()
        lock.unlock()
        for transport in all {
            transport.serverClosed()
        }
    }

    // MARK: - Server side

    func connected(_ transport: FakeRelayTransport, url: URL?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if let url {
            urls.append(url)
        }
        guard !refusesConnections else {
            return false
        }
        connections[transport.connection] = transport
        return true
    }

    func disconnected(_ connection: Int) {
        lock.lock()
        connections[connection] = nil
        for topic in subscriptions.keys {
            subscriptions[topic]?.remove(connection)
        }
        lock.unlock()
    }

    func receive(_ text: String, from connection: Int) {
        guard let json = try? JSONParser.parse(text), let message = RPCMessage(json: json) else {
            return
        }

        switch message {
        case let .response(id, _):
            lock.lock()
            if deliveriesAwaitingAck.remove(id) != nil {
                acknowledged += 1
            }
            lock.unlock()
        case let .request(id, method, params):
            handle(id: id, method: method, params: params, from: connection)
        }
    }

    private func respond(_ id: Int64, _ result: JSONValue, to connection: Int) {
        lock.lock()
        let transport = connections[connection]
        lock.unlock()
        transport?.deliver(RPCMessage.response(id: id, result: .response(AnyCodable(json: result))).text)
    }

    private func handle(id: Int64, method: String, params: JSONValue, from connection: Int) {
        switch method {
        case "irn_subscribe":
            guard let topic = params["topic"]?.stringValue else {
                return
            }
            respond(id, .string(subscribe(topic, connection: connection)), to: connection)
            flushHeld(topic, to: connection)
        case "irn_batchSubscribe":
            let topics = (params["topics"]?.arrayValue ?? []).compactMap(\.stringValue)
            let ids = topics.map { JSONValue.string(subscribe($0, connection: connection)) }
            respond(id, .array(ids), to: connection)
            for topic in topics {
                flushHeld(topic, to: connection)
            }
        case "irn_unsubscribe":
            if let topic = params["topic"]?.stringValue {
                lock.lock()
                subscriptions[topic]?.remove(connection)
                lock.unlock()
            }
            respond(id, .bool(true), to: connection)
        case "irn_publish":
            guard
                let topic = params["topic"]?.stringValue,
                let message = params["message"]?.stringValue,
                let ttl = params["ttl"]?.int64Value,
                let tag = params["tag"]?.int64Value
            else {
                return
            }
            respond(id, .bool(true), to: connection)
            publish(
                topic: topic,
                message: message,
                ttl: Int(ttl),
                tag: Int(tag),
                prompt: params["prompt"]?.boolValue == true,
                from: connection,
                attestation: nil
            )
        case "irn_batchFetchMessages":
            let topics = (params["topics"]?.arrayValue ?? []).compactMap(\.stringValue)
            lock.lock()
            var messages: [JSONValue] = []
            for topic in topics {
                for entry in held.removeValue(forKey: topic) ?? [] {
                    messages.append(.object([
                        "topic": .string(entry.topic),
                        "message": .string(entry.message),
                        "publishedAt": .int(entry.publishedAt),
                        "tag": .int(entry.tag)
                    ]))
                }
            }
            lock.unlock()
            respond(id, .object(["messages": .array(messages), "hasMore": .bool(false)]), to: connection)
        default:
            lock.lock()
            let transport = connections[connection]
            lock.unlock()
            transport?.deliver(RPCMessage.response(id: id, result: .error(.methodNotFound)).text)
        }
    }

    private func subscribe(_ topic: String, connection: Int) -> String {
        lock.lock()
        subscriptions[topic, default: []].insert(connection)
        lock.unlock()
        return Hex.encode(Data(topic.utf8.prefix(16)))
    }

    private func flushHeld(_ topic: String, to connection: Int) {
        lock.lock()
        let entries = held.removeValue(forKey: topic) ?? []
        lock.unlock()
        for entry in entries {
            send(entry.topic, entry.message, entry.publishedAt, entry.tag, entry.attestation, to: connection)
        }
    }

    private func publish(
        topic: String,
        message: String,
        ttl: Int,
        tag: Int,
        prompt: Bool,
        from connection: Int,
        attestation: String?
    ) {
        let publishedAt = Int64(Date().timeIntervalSince1970 * 1000)
        lock.lock()
        published.append(Published(topic: topic, message: message, ttl: ttl, tag: tag, prompt: prompt, connection: connection))
        let receivers = (subscriptions[topic] ?? []).subtracting([connection])
        if receivers.isEmpty {
            held[topic, default: []].append(
                Held(topic: topic, message: message, publishedAt: publishedAt, tag: tag, attestation: attestation)
            )
        }
        lock.unlock()

        for receiver in receivers {
            send(topic, message, publishedAt, tag, attestation, to: receiver)
        }
    }

    private func send(_ topic: String, _ message: String, _ publishedAt: Int64, _ tag: Int, _ attestation: String?, to connection: Int) {
        lock.lock()
        let transport = connections[connection]
        delivered += 1
        let id = Int64(delivered) + 9_000_000
        deliveriesAwaitingAck.insert(id)
        lock.unlock()

        var data: [String: JSONValue] = [
            "topic": .string(topic),
            "message": .string(message),
            "publishedAt": .int(publishedAt),
            "tag": .int(tag)
        ]
        if let attestation {
            data["attestation"] = .string(attestation)
        }
        let request = RPCMessage.request(
            id: id,
            method: "irn_subscription",
            params: .object(["id": .string("sub"), "data": .object(data)])
        )
        transport?.deliver(request.text)
    }
}

final class FakeRelayTransport: RelayTransport, @unchecked Sendable {
    let events: AsyncStream<RelayTransportEvent>
    let connection: Int
    private let continuation: AsyncStream<RelayTransportEvent>.Continuation
    private weak var relay: FakeRelay?
    private let lock = NSLock()
    private var isOpen = false
    private var finished = false

    init(relay: FakeRelay, connection: Int) {
        self.relay = relay
        self.connection = connection
        var continuation: AsyncStream<RelayTransportEvent>.Continuation!
        events = AsyncStream(bufferingPolicy: .unbounded) { continuation = $0 }
        self.continuation = continuation
    }

    func connect(request: URLRequest) {
        DispatchQueue.global().async {
            guard let relay = self.relay, relay.connected(self, url: request.url) else {
                self.finish(.failed("refused"))
                return
            }
            self.lock.lock()
            self.isOpen = true
            self.lock.unlock()
            self.continuation.yield(.opened)
        }
    }

    private func isUsable() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return isOpen && !finished
    }

    func send(text: String) async throws {
        guard isUsable() else {
            throw RelayTransportError.notConnected
        }
        guard let relay = self.relay else {
            throw RelayTransportError.notConnected
        }
        let connection = self.connection
        relay.queue.async {
            relay.receive(text, from: connection)
        }
    }

    func sendPing() async throws {
        guard isUsable() else {
            throw RelayTransportError.notConnected
        }
    }

    func close() {
        relay?.disconnected(connection)
        finish(.closed(code: 1000, reason: "closed by client"))
    }

    func deliver(_ text: String) {
        guard isUsable() else {
            return
        }
        continuation.yield(.text(text))
    }

    func serverClosed() {
        finish(.closed(code: 1001, reason: "relay restarted"))
    }

    private func finish(_ event: RelayTransportEvent) {
        lock.lock()
        guard !finished else {
            lock.unlock()
            return
        }
        finished = true
        isOpen = false
        lock.unlock()
        continuation.yield(event)
        continuation.finish()
    }
}
