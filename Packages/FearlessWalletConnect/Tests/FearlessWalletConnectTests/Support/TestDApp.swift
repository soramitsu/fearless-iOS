import Combine
import CryptoKit
import Foundation
import XCTest
@testable import FearlessWalletConnect

/// A dApp on the other side of the relay, written against the protocol in the test: it proposes, takes the
/// wallet's answer and settlement, and sends requests. Its relay connection is a separate client of the same relay.
actor TestDApp {
    struct Received: Equatable {
        let topic: String
        let message: RPCMessage
    }

    let metadata: AppMetadata
    private let relay: RelayConnection
    private let selfKey = Curve25519.KeyAgreement.PrivateKey()
    private var keys: [String: Data] = [:]
    private var inbox: [Received] = []
    private var listening: Task<Void, Never>?
    private let identifiers = RPCIdentifierGenerator()
    var acknowledgesSettlement = true
    private(set) var pairingTopic: String?
    private(set) var sessionTopic: String?
    private(set) var proposalId: Int64?

    var publicKey: String {
        Hex.encode(selfKey.publicKey.rawRepresentation)
    }

    init(relay factory: RelayTransportFactory, name: String = "Public dApp", url: String = "https://dapp.example") {
        metadata = AppMetadata(name: name, description: "", url: url, icons: ["https://dapp.example/icon.png"])
        relay = RelayConnection(
            configuration: .init(url: URL(string: "wss://relay.test")!, projectId: "public-test-project", userAgent: "dapp", bundleId: nil),
            transportFactory: factory,
            tokenProvider: { audience in
                try RelayAuth.token(seed: Data(repeating: 7, count: 32), audience: audience, subject: "dapp", issuedAt: 1)
            },
            clock: .system,
            logger: SilentWalletConnectLogger()
        )
    }

    func setAcknowledgesSettlement(_ value: Bool) {
        acknowledgesSettlement = value
    }

    func startListening() {
        guard listening == nil else {
            return
        }
        let messages = relay.messages
        listening = Task { [weak self] in
            for await message in messages {
                await self?.receive(message)
            }
        }
    }

    func close() async {
        listening?.cancel()
        await relay.shutdown()
    }

    private func receive(_ relayMessage: RelayMessage) async {
        guard
            let key = keys[relayMessage.topic],
            let plaintext = try? WalletConnectCrypto.open(relayMessage.message, symmetricKey: key),
            let json = try? JSONParser.parse(plaintext),
            let message = RPCMessage(json: json)
        else {
            return
        }
        inbox.append(Received(topic: relayMessage.topic, message: message))

        if case let .request(id, method, _) = message {
            switch method {
            case "wc_sessionSettle" where acknowledgesSettlement:
                try? await send(.response(id: id, result: .response(AnyCodable(json: .bool(true)))), on: relayMessage.topic, tag: 1103)
            case "wc_sessionPing":
                try? await send(.response(id: id, result: .response(AnyCodable(json: .bool(true)))), on: relayMessage.topic, tag: 1115)
            case "wc_pairingPing":
                try? await send(.response(id: id, result: .response(AnyCodable(json: .bool(true)))), on: relayMessage.topic, tag: 1003)
            case "wc_sessionDelete":
                try? await send(.response(id: id, result: .response(AnyCodable(json: .bool(true)))), on: relayMessage.topic, tag: 1113)
            default:
                break
            }
        }
    }

    // MARK: - Pairing and proposal

    /// Creates a pairing and publishes a proposal on it before the wallet listens; returns the pairing link.
    func propose(
        required: JSONValue = .object([:]),
        optional: JSONValue = .object([
            "eip155": .object([
                "chains": .array([.string("eip155:1")]),
                "methods": .array([.string("personal_sign")]),
                "events": .array([.string("chainChanged")])
            ])
        ]),
        proposerPublicKey: String? = nil,
        expiryTimestamp: Int64? = nil,
        extra: [String: JSONValue] = [:]
    ) async throws -> WalletConnectURI {
        startListening()
        let symKey = try WalletConnectCrypto.randomKey()
        let topic = WalletConnectCrypto.topic(forSymmetricKey: symKey)
        keys[topic] = symKey
        pairingTopic = topic
        let expiry = expiryTimestamp ?? Int64(Date().timeIntervalSince1970) + 300

        var params: [String: JSONValue] = [
            "relays": .array([.object(["protocol": .string("irn")])]),
            "proposer": .object(["publicKey": .string(proposerPublicKey ?? publicKey), "metadata": metadata.json]),
            "requiredNamespaces": required,
            "optionalNamespaces": optional,
            "expiryTimestamp": .int(expiry),
            "pairingTopic": .string(topic)
        ]
        for (key, value) in extra {
            params[key] = value
        }
        let id = identifiers.next(now: Date())
        proposalId = id
        // The dApp listens on the pairing first; nobody else does yet, so the relay holds the proposal for the wallet.
        try await relay.subscribe([topic])
        try await send(.request(id: id, method: "wc_sessionPropose", params: .object(params)), on: topic, tag: 1100)
        return WalletConnectURI(topic: topic, symKey: Hex.encode(symKey), expiryTimestamp: UInt64(expiry))
    }

    /// Waits for the wallet's answer to the proposal; on approval, listens on the session topic.
    func proposalAnswer(timeout: TimeInterval = 5) async throws -> RPCResult {
        guard let pairingTopic, let proposalId else {
            throw TestFailure("no proposal")
        }
        let received = try await next(timeout: timeout) { received in
            guard received.topic == pairingTopic, case let .response(id, _) = received.message else {
                return false
            }
            return id == proposalId
        }
        guard case let .response(_, result) = received.message else {
            throw TestFailure("not a response")
        }
        if
            case let .response(value) = result,
            let responder = value.value["responderPublicKey"]?.stringValue,
            let responderKey = Hex.decodeKey(responder) {
            let symKey = try WalletConnectCrypto.deriveSymmetricKey(privateKey: selfKey, peerPublicKey: responderKey)
            let topic = WalletConnectCrypto.topic(forSymmetricKey: symKey)
            keys[topic] = symKey
            sessionTopic = topic
            try await relay.subscribe([topic])
        }
        return result
    }

    func settlement(timeout: TimeInterval = 5) async throws -> JSONValue {
        guard let sessionTopic else {
            throw TestFailure("no session")
        }
        let received = try await next(timeout: timeout) { $0.topic == sessionTopic && $0.message.method == "wc_sessionSettle" }
        guard case let .request(_, _, params) = received.message else {
            throw TestFailure("not a request")
        }
        return params
    }

    // MARK: - Requests

    /// Sends a request in the session and returns its id.
    @discardableResult
    func sendRequest(
        method: String,
        params: JSONValue,
        chainId: String,
        expiryTimestamp: Int64? = nil,
        topic: String? = nil
    ) async throws -> Int64 {
        guard let target = topic ?? sessionTopic else {
            throw TestFailure("no session")
        }
        var request: [String: JSONValue] = ["method": .string(method), "params": params]
        if let expiryTimestamp {
            request["expiryTimestamp"] = .int(expiryTimestamp)
        }
        let id = identifiers.next(now: Date())
        try await send(
            .request(id: id, method: "wc_sessionRequest", params: .object(["request": .object(request), "chainId": .string(chainId)])),
            on: target,
            tag: 1108
        )
        return id
    }

    func response(to id: Int64, topic: String? = nil, timeout: TimeInterval = 5) async throws -> RPCResult {
        let target = topic ?? sessionTopic
        let received = try await next(timeout: timeout) { received in
            guard received.topic == target, case let .response(responseId, _) = received.message else {
                return false
            }
            return responseId == id
        }
        guard case let .response(_, result) = received.message else {
            throw TestFailure("not a response")
        }
        return result
    }

    func request(named method: String, topic: String? = nil, timeout: TimeInterval = 5) async throws -> RPCMessage {
        let target = topic ?? sessionTopic
        return try await next(timeout: timeout) { $0.topic == target && $0.message.method == method }.message
    }

    func send(_ message: RPCMessage, on topic: String, tag: Int) async throws {
        guard let key = keys[topic] else {
            throw TestFailure("no key for topic")
        }
        let envelope = try WalletConnectCrypto.seal(Data(message.text.utf8), symmetricKey: key)
        try await relay.publish(topic: topic, message: envelope, ttl: 300, tag: tag, prompt: false)
    }

    /// Takes over a session whose key the test knows, as a dApp paired with an earlier wallet build would hold it.
    func adoptSession(topic: String, symmetricKey: Data) async throws {
        startListening()
        keys[topic] = symmetricKey
        sessionTopic = topic
        try await relay.subscribe([topic])
    }

    func sealed(_ message: RPCMessage, on topic: String) throws -> String {
        guard let key = keys[topic] else {
            throw TestFailure("no key for topic")
        }
        return try WalletConnectCrypto.seal(Data(message.text.utf8), symmetricKey: key)
    }

    func received() -> [Received] {
        inbox
    }

    private func next(timeout: TimeInterval, where predicate: (Received) -> Bool) async throws -> Received {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let index = inbox.firstIndex(where: predicate) {
                return inbox.remove(at: index)
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw TestFailure("timed out waiting for the wallet")
    }
}

struct TestFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

extension RPCMessage {
    var method: String? {
        if case let .request(_, method, _) = self {
            return method
        }
        return nil
    }

    var result: RPCResult? {
        if case let .response(_, result) = self {
            return result
        }
        return nil
    }
}

/// Collects what a client reports.
final class EventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [WalletConnectClient.Event] = []
    private var cancellable: AnyCancellable?

    init(_ client: WalletConnectClient) {
        cancellable = client.events.sink { [weak self] event in
            guard let self else {
                return
            }
            self.lock.lock()
            self.events.append(event)
            self.lock.unlock()
        }
    }

    var all: [WalletConnectClient.Event] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    func proposals() -> [(Session.Proposal, VerifyContext)] {
        all.compactMap {
            if case let .sessionProposal(proposal, context) = $0 {
                return (proposal, context)
            }
            return nil
        }
    }

    func requests() -> [(Request, VerifyContext)] {
        all.compactMap {
            if case let .sessionRequest(request, context) = $0 {
                return (request, context)
            }
            return nil
        }
    }

    func waitForProposal(timeout: TimeInterval = 5) async throws -> Session.Proposal {
        try await waitFor(timeout: timeout) { self.proposals().last?.0 }
    }

    /// The proposal that arrived on one pairing, when several dApps propose.
    func waitForProposal(pairingTopic: String, timeout: TimeInterval = 5) async throws -> Session.Proposal {
        try await waitFor(timeout: timeout) { self.proposals().map(\.0).first { $0.pairingTopic == pairingTopic } }
    }

    func waitForRequest(count: Int = 1, timeout: TimeInterval = 5) async throws -> Request {
        try await waitFor(timeout: timeout) {
            let requests = self.requests()
            return requests.count >= count ? requests[count - 1].0 : nil
        }
    }

    func waitFor<T>(timeout: TimeInterval = 5, _ value: () -> T?) async throws -> T {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let found = value() {
                return found
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        throw TestFailure("timed out waiting for the client")
    }

    func contains(_ predicate: (WalletConnectClient.Event) -> Bool) -> Bool {
        all.contains(where: predicate)
    }
}

/// A clock the test moves forward; timers still wait real time.
final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var offset: TimeInterval = 0

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        offset += seconds
        lock.unlock()
    }

    var clock: WalletConnectClock {
        WalletConnectClock(
            now: { [self] in
                lock.lock()
                defer { lock.unlock() }
                return Date().addingTimeInterval(offset)
            },
            sleep: WalletConnectClock.system.sleep
        )
    }
}

/// An offline Verify service: every lookup fails, so contexts stay unknown.
let offlineVerify = VerifyClient(fetch: { _ in (404, Data()) })

func waitUntil(timeout: TimeInterval = 5, _ condition: () async -> Bool) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() {
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    throw TestFailure("timed out")
}
