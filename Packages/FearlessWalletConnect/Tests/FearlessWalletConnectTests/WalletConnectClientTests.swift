import CryptoKit
import XCTest
@testable import FearlessWalletConnect

// Public fixtures only: no live relay, no network, no real accounts.
let fearlessMetadata = AppMetadata(
    name: "Fearless wallet",
    description: "Defi wallet",
    url: "https://fearlesswallet.io",
    icons: [],
    redirect: .init(native: "fearless://", universal: nil)
)
let evmAddress = "0x1111111111111111111111111111111111111111"
let ethereum = Blockchain("eip155:1")!
let grant = ["eip155": SessionNamespace(
    chains: [ethereum],
    accounts: [Account(blockchain: ethereum, address: evmAddress)!],
    methods: ["personal_sign"],
    events: ["chainChanged"]
)]

func makeWallet(
    relay: FakeRelay,
    store: InMemoryWalletConnectStore = InMemoryWalletConnectStore(),
    legacy: LegacyWalletConnectStorage? = nil,
    clock: WalletConnectClock = .system,
    verify: VerifyClient = offlineVerify
) async throws -> WalletConnectClient {
    let wallet = WalletConnectClient(
        configuration: .init(
            projectId: "public-test-project",
            relayURL: URL(string: "wss://relay.test")!,
            metadata: fearlessMetadata,
            bundleId: "jp.co.soramitsu.fearlesswallet",
            userAgent: "wc-2/fearless-wallet-tests"
        ),
        stateStore: store,
        secretStore: store,
        legacyStorage: legacy,
        transportFactory: relay,
        verify: verify,
        clock: clock
    )
    try await wallet.start()
    return wallet
}

/// A settled session between a test dApp and the wallet.
func settle(
    _ wallet: WalletConnectClient,
    _ dapp: TestDApp,
    events: EventRecorder,
    namespaces: [String: SessionNamespace] = grant
) async throws -> Session {
    let uri = try await dapp.propose()
    try await wallet.pair(uri: uri)
    let proposal = try await events.waitForProposal(pairingTopic: uri.topic)
    let session = try await wallet.approve(proposalId: proposal.id, namespaces: namespaces)
    _ = try await dapp.proposalAnswer()
    _ = try await dapp.settlement()
    try await waitUntil { await wallet.isAcknowledged(topic: session.topic) }
    return session
}

final class WalletConnectClientTests: XCTestCase {
    func testProposalSentBeforeTheWalletListensIsSettledAnsweredAndEnded() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)

        let uri = try await dapp.propose()
        // Nobody else listens yet: the relay holds the proposal for the wallet.
        XCTAssertEqual(relay.heldCount(for: uri.topic), 1)

        try await wallet.pair(uri: uri)
        let proposal = try await events.waitForProposal()
        XCTAssertEqual(relay.heldCount(for: uri.topic), 0)
        XCTAssertEqual(proposal.proposer.name, "Public dApp")
        XCTAssertEqual(proposal.pairingTopic, uri.topic)
        XCTAssertEqual(proposal.optionalNamespaces?["eip155"]?.chains, [ethereum])
        XCTAssertEqual(events.proposals().last?.1.validation, .unknown)

        let session = try await wallet.approve(proposalId: proposal.id, namespaces: grant)
        guard case let .response(answer) = try await dapp.proposalAnswer() else {
            return XCTFail("The proposal was refused")
        }
        let responder = try XCTUnwrap(answer.value["responderPublicKey"]?.stringValue)
        XCTAssertEqual(answer.value["relay"]?["protocol"]?.stringValue, "irn")

        let settlement = try await dapp.settlement()
        XCTAssertEqual(settlement["controller"]?["publicKey"]?.stringValue, responder)
        XCTAssertEqual(settlement["controller"]?["metadata"]?["name"]?.stringValue, "Fearless wallet")
        XCTAssertEqual(settlement["namespaces"]?["eip155"]?["accounts"], .array([.string("eip155:1:\(evmAddress)")]))
        let expiry = try XCTUnwrap(settlement["expiry"]?.int64Value)
        XCTAssertEqual(Double(expiry), Date().timeIntervalSince1970 + 7 * 86400, accuracy: 30)
        try await waitUntil { await wallet.isAcknowledged(topic: session.topic) }
        let dappSessionTopic = await dapp.sessionTopic
        XCTAssertEqual(dappSessionTopic, session.topic)

        // Each method's relay tag and lifetime.
        XCTAssertEqual(relay.publishedMessages(on: uri.topic).map(\.tag), [1100, 1101])
        XCTAssertEqual(relay.publishedMessages(on: uri.topic).map(\.ttl), [300, 300])
        XCTAssertEqual(relay.publishedMessages(on: session.topic).map(\.tag), [1102, 1103])

        let id = try await dapp.sendRequest(
            method: "personal_sign",
            params: .array([.string("0x48656c6c6f"), .string(evmAddress)]),
            chainId: "eip155:1"
        )
        let request = try await events.waitForRequest()
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.topic, session.topic)
        XCTAssertEqual(request.method, "personal_sign")
        XCTAssertEqual(request.chainId, ethereum)
        XCTAssertEqual(try request.params.get([String].self), ["0x48656c6c6f", evmAddress])

        try await wallet.respond(topic: session.topic, requestId: id, response: .response(AnyCodable("0xsigned")))
        let response = try await dapp.response(to: id)
        XCTAssertEqual(response, .response(AnyCodable("0xsigned")))
        XCTAssertEqual(relay.publishedMessages(on: session.topic).last.map { [$0.tag, $0.ttl] }, [1109, 900])

        try await wallet.disconnect(topic: session.topic)
        guard case let .request(_, _, params) = try await dapp.request(named: "wc_sessionDelete") else {
            return XCTFail("No disconnection")
        }
        XCTAssertEqual(params["code"]?.int64Value, 6000)
        XCTAssertTrue(wallet.currentSessions.isEmpty)
        let secretsAfterDisconnect = await wallet.storedSecrets()
        XCTAssertNil(secretsAfterDisconnect.keys[session.topic])
        XCTAssertTrue(events.contains {
            if case let .sessionDeleted(topic) = $0 {
                return topic == session.topic
            }
            return false
        })
        let delete = try XCTUnwrap(relay.publishedMessages(on: session.topic).first { $0.tag == 1112 })
        XCTAssertEqual(delete.ttl, 86400)

        // Every delivery was acknowledged to the relay.
        try await waitUntil { relay.unacknowledgedDeliveries == 0 }
        await dapp.close()
    }

    func testRefusalTellsTheDAppAndIsFinal() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)

        try await wallet.pair(uri: try await dapp.propose())
        let proposal = try await events.waitForProposal()
        try await wallet.reject(proposalId: proposal.id, reason: .userRejected)

        let answer = try await dapp.proposalAnswer()
        XCTAssertEqual(answer, .error(JSONRPCError(code: 5000, message: "User rejected.")))
        let refusedPairing = await dapp.pairingTopic
        let pairingTopic = try XCTUnwrap(refusedPairing)
        XCTAssertEqual(relay.publishedMessages(on: pairingTopic).last?.tag, 1120)

        // A refused proposal cannot be approved or refused again, and nothing more reaches the dApp.
        let published = relay.allPublished.count
        do {
            _ = try await wallet.approve(proposalId: proposal.id, namespaces: grant)
            XCTFail("Approved a refused proposal")
        } catch WalletConnectClient.ClientError.proposalNotFound {}
        do {
            try await wallet.reject(proposalId: proposal.id, reason: .userRejected)
            XCTFail("Refused twice")
        } catch WalletConnectClient.ClientError.proposalNotFound {}
        XCTAssertEqual(relay.allPublished.count, published)
        await dapp.close()
    }

    func testARedeliveredRequestIsOfferedOnce() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(wallet, dapp, events: events)

        let request = RPCMessage.request(
            id: 42,
            method: "wc_sessionRequest",
            params: .object([
                "request": .object(["method": .string("personal_sign"), "params": .array([.string("0x01"), .string(evmAddress)])]),
                "chainId": .string("eip155:1")
            ])
        )
        let envelope = try await dapp.sealed(request, on: session.topic)
        relay.inject(topic: session.topic, message: envelope)
        relay.inject(topic: session.topic, message: envelope)
        // The same request again in a new envelope.
        relay.inject(topic: session.topic, message: try await dapp.sealed(request, on: session.topic))

        _ = try await events.waitForRequest()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(events.requests().count, 1)
        await dapp.close()
    }

    func testRequestsOutsideTheSessionAreRefusedWithTheProtocolCodes() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        _ = try await settle(wallet, dapp, events: events)

        let otherChain = try await dapp.sendRequest(method: "personal_sign", params: .array([]), chainId: "eip155:137")
        let otherChainAnswer = try await dapp.response(to: otherChain)
        XCTAssertEqual(otherChainAnswer.errorCode, 5100)

        let otherMethod = try await dapp.sendRequest(method: "eth_sign", params: .array([]), chainId: "eip155:1")
        let otherMethodAnswer = try await dapp.response(to: otherMethod)
        XCTAssertEqual(otherMethodAnswer.errorCode, 5101)

        let malformed = try await dapp.sendRequest(method: "", params: .null, chainId: "eip155:1")
        let malformedAnswer = try await dapp.response(to: malformed)
        XCTAssertEqual(malformedAnswer.errorCode, 1001)

        let expired = try await dapp.sendRequest(
            method: "personal_sign",
            params: .array([]),
            chainId: "eip155:1",
            expiryTimestamp: Int64(Date().timeIntervalSince1970) - 1
        )
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(events.requests().isEmpty)
        let dappInbox = await dapp.received()
        XCTAssertFalse(dappInbox.contains { $0.message.id == expired })
        await dapp.close()
    }

    func testTheDAppCannotUpdateOrExtendASessionFearlessControls() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(wallet, dapp, events: events)

        let updates: [(String, Int, JSONValue)] = [
            ("wc_sessionUpdate", 3003, .object(["namespaces": .object([:])])),
            ("wc_sessionExtend", 3004, .object([:])),
            ("wc_somethingNew", 10001, .object([:]))
        ]
        for (index, (method, code, params)) in updates.enumerated() {
            let id = Int64(1000 + index)
            try await dapp.send(.request(id: id, method: method, params: params), on: session.topic, tag: 0)
            let answer = try await dapp.response(to: id)
            XCTAssertEqual(answer.errorCode, code, method)
        }

        let storedSession = await wallet.storedSession(topic: session.topic)
        let stored = try XCTUnwrap(storedSession)
        XCTAssertEqual(stored.namespaces, grant)
        XCTAssertEqual(stored.expiry, Int64(session.expiryDate.timeIntervalSince1970))

        try await dapp.send(.request(id: 2000, method: "wc_sessionPing", params: .object([:])), on: session.topic, tag: 1114)
        let pong = try await dapp.response(to: 2000)
        XCTAssertEqual(pong, .response(AnyCodable(json: .bool(true))))
        try await wallet.ping(topic: session.topic)
        await dapp.close()
    }

    func testRequestsBeforeTheSettlementIsConfirmedAreRefused() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        await dapp.setAcknowledgesSettlement(false)

        try await wallet.pair(uri: try await dapp.propose())
        let proposal = try await events.waitForProposal()
        let session = try await wallet.approve(proposalId: proposal.id, namespaces: grant)
        _ = try await dapp.proposalAnswer()
        _ = try await dapp.settlement()

        let id = try await dapp.sendRequest(method: "personal_sign", params: .array([]), chainId: "eip155:1")
        let unsettledAnswer = try await dapp.response(to: id)
        XCTAssertEqual(unsettledAnswer.errorCode, 3001)
        XCTAssertTrue(events.requests().isEmpty)
        let acknowledged = await wallet.isAcknowledged(topic: session.topic)
        XCTAssertFalse(acknowledged)
        await dapp.close()
    }

    func testASettlementTheDAppRefusesEndsTheSession() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        await dapp.setAcknowledgesSettlement(false)

        try await wallet.pair(uri: try await dapp.propose())
        let proposal = try await events.waitForProposal()
        let session = try await wallet.approve(proposalId: proposal.id, namespaces: grant)
        _ = try await dapp.proposalAnswer()
        _ = try await dapp.settlement()
        let settlements = await wallet.storedState().settlements
        let settleId = try XCTUnwrap(settlements[session.topic])

        try await dapp.send(.response(id: settleId, result: .error(JSONRPCError(code: 7000, message: "Session settlement failed."))), on: session.topic, tag: 1103)
        try await waitUntil { wallet.currentSessions.isEmpty }
        let secretsAfterRefusal = await wallet.storedSecrets()
        XCTAssertNil(secretsAfterRefusal.keys[session.topic])
        await dapp.close()
    }

    func testTheDAppEndingASessionForgetsIt() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(wallet, dapp, events: events)

        try await dapp.send(
            .request(id: 77, method: "wc_sessionDelete", params: .object(["code": .int(6000), "message": .string("User disconnected.")])),
            on: session.topic,
            tag: 1112
        )
        let deleteAnswer = try await dapp.response(to: 77)
        XCTAssertEqual(deleteAnswer, .response(AnyCodable(json: .bool(true))))
        try await waitUntil { wallet.currentSessions.isEmpty }
        // Only the dApp still listens on the topic.
        try await waitUntil { relay.subscriberCount(session.topic) <= 1 }
        let forgotten = await wallet.storedState().forgottenTopics
        XCTAssertTrue(forgotten.contains(session.topic))
        await dapp.close()
    }

    func testProposalsRequestsAndSessionsExpire() async throws {
        let relay = FakeRelay()
        let testClock = TestClock()
        let wallet = try await makeWallet(relay: relay, clock: testClock.clock)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)

        // A proposal nobody decided on.
        let other = TestDApp(relay: relay, name: "Slow dApp")
        try await wallet.pair(uri: try await other.propose())
        let pending = try await events.waitForProposal()

        let session = try await settle(wallet, dapp, events: events)
        let id = try await dapp.sendRequest(method: "personal_sign", params: .array([]), chainId: "eip155:1")
        _ = try await events.waitForRequest()

        testClock.advance(16 * 60)
        await wallet.sweep()
        XCTAssertTrue(events.contains {
            if case let .proposalExpired(expired) = $0 {
                return expired == pending.id
            }
            return false
        })
        XCTAssertTrue(events.contains {
            if case let .requestExpired(expired, topic) = $0 {
                return expired == id && topic == session.topic
            }
            return false
        })
        do {
            _ = try await wallet.approve(proposalId: pending.id, namespaces: grant)
            XCTFail("Approved an expired proposal")
        } catch WalletConnectClient.ClientError.proposalNotFound {}
        XCTAssertEqual(wallet.currentSessions.map(\.topic), [session.topic])

        testClock.advance(7 * 86400)
        await wallet.sweep()
        XCTAssertTrue(wallet.currentSessions.isEmpty)
        try await waitUntil { relay.subscriberCount(session.topic) <= 1 }
        await dapp.close()
        await other.close()
    }

    func testASessionSurvivesARestartAndAHeldRequestArrivesAfterIt() async throws {
        let relay = FakeRelay()
        let store = InMemoryWalletConnectStore()
        let first = try await makeWallet(relay: relay, store: store)
        let firstEvents = EventRecorder(first)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(first, dapp, events: firstEvents)
        let identity = try await first.clientId()
        await first.stop()

        // The wallet is not listening: the relay holds the request.
        let id = try await dapp.sendRequest(method: "personal_sign", params: .array([.string("0x01"), .string(evmAddress)]), chainId: "eip155:1")
        try await waitUntil { relay.heldCount(for: session.topic) == 1 }

        let second = WalletConnectClient(
            configuration: .init(
                projectId: "public-test-project",
                relayURL: URL(string: "wss://relay.test")!,
                metadata: fearlessMetadata,
                bundleId: nil,
                userAgent: "wc-2/fearless-wallet-tests"
            ),
            stateStore: store,
            secretStore: store,
            transportFactory: relay,
            verify: offlineVerify
        )
        let secondEvents = EventRecorder(second)
        try await second.start()
        XCTAssertEqual(second.currentSessions.map(\.topic), [session.topic])
        let secondIdentity = try await second.clientId()
        XCTAssertEqual(secondIdentity, identity)

        let request = try await secondEvents.waitForRequest()
        XCTAssertEqual(request.id, id)
        try await second.respond(topic: session.topic, requestId: id, response: .error(JSONRPCError(code: 4001, message: "User rejected request")))
        let refusal = try await dapp.response(to: id)
        XCTAssertEqual(refusal.errorCode, 4001)
        await dapp.close()
    }

    func testSuspendedWalletGetsWhatArrivedInTheBackground() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(wallet, dapp, events: events)

        await wallet.suspend()
        try await waitUntil { relay.openConnections == 1 }
        let id = try await dapp.sendRequest(method: "personal_sign", params: .array([]), chainId: "eip155:1")
        try await waitUntil { relay.heldCount(for: session.topic) == 1 }
        XCTAssertTrue(events.requests().isEmpty)

        await wallet.resume()
        let request = try await events.waitForRequest()
        XCTAssertEqual(request.id, id)
        await dapp.close()
    }

    func testReconnectsWithAFreshSignInAfterTheRelayDropsTheConnection() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(wallet, dapp, events: events)

        let first = try XCTUnwrap(relay.urls(userAgent: "wc-2/fearless-wallet-tests").first)
        let query = Dictionary(uniqueKeysWithValues: (URLComponents(url: first, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(first.host, "relay.test")
        XCTAssertEqual(query["projectId"], "public-test-project")
        XCTAssertEqual(query["bundleId"], "jp.co.soramitsu.fearlesswallet")
        XCTAssertEqual(query["ua"], "wc-2/fearless-wallet-tests")
        let token = try XCTUnwrap(query["auth"])
        XCTAssertEqual(token.split(separator: ".").count, 3)
        XCTAssertEqual(RelayAuth.payload(ofToken: token)?["aud"]?.stringValue, "wss://relay.test")
        let walletIdentity = try await wallet.clientId()
        XCTAssertEqual(RelayAuth.payload(ofToken: token)?["iss"]?.stringValue, walletIdentity)

        let urlsBefore = relay.urls(userAgent: "wc-2/fearless-wallet-tests").count
        relay.disconnectAll()
        // Both clients reconnect after their first back-off, each with a new sign-in token.
        try await waitUntil(timeout: 10) {
            relay.urls(userAgent: "wc-2/fearless-wallet-tests").count > urlsBefore && relay.subscriberCount(session.topic) == 2
        }
        let reconnected = try XCTUnwrap(relay.urls(userAgent: "wc-2/fearless-wallet-tests").last)
        let newToken = URLComponents(url: reconnected, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "auth" }?.value
        XCTAssertNotEqual(newToken, token)

        let id = try await dapp.sendRequest(method: "personal_sign", params: .array([]), chainId: "eip155:1")
        let afterReconnect = try await events.waitForRequest(timeout: 10)
        XCTAssertEqual(afterReconnect.id, id)
        await dapp.close()
    }

    func testASessionThatExpiredWhileTheAppWasNotRunningIsEndedOnStart() async throws {
        let relay = FakeRelay()
        let store = InMemoryWalletConnectStore()
        let testClock = TestClock()
        let first = try await makeWallet(relay: relay, store: store, clock: testClock.clock)
        let events = EventRecorder(first)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(first, dapp, events: events)
        await first.stop()

        testClock.advance(8 * 86400)
        let second = WalletConnectClient(
            configuration: .init(
                projectId: "public-test-project",
                relayURL: URL(string: "wss://relay.test")!,
                metadata: fearlessMetadata,
                bundleId: nil,
                userAgent: "wc-2/fearless-wallet-tests"
            ),
            stateStore: store,
            secretStore: store,
            transportFactory: relay,
            verify: offlineVerify,
            clock: testClock.clock
        )
        let secondEvents = EventRecorder(second)
        try await second.start()

        XCTAssertTrue(second.currentSessions.isEmpty)
        XCTAssertTrue(secondEvents.contains {
            if case let .sessionDeleted(topic) = $0 {
                return topic == session.topic
            }
            return false
        })
        let secrets = await second.storedSecrets()
        XCTAssertNil(secrets.keys[session.topic])
        await dapp.close()
        await second.stop()
    }

    func testDisconnectingWorksWithoutTheRelay() async throws {
        let relay = FakeRelay()
        let store = InMemoryWalletConnectStore()
        let wallet = try await makeWallet(relay: relay, store: store)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        let session = try await settle(wallet, dapp, events: events)

        relay.refusesConnections = true
        relay.disconnectAll()
        try await wallet.disconnect(topic: session.topic)

        XCTAssertTrue(wallet.currentSessions.isEmpty)
        let secrets = await wallet.storedSecrets()
        XCTAssertNil(secrets.keys[session.topic])
        await dapp.close()
        await wallet.stop()
    }

    func testPairingLinksThatCannotBeUsed() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        _ = try await settle(wallet, dapp, events: events)
        let settledPairing = await dapp.pairingTopic
        let pairingTopic = try XCTUnwrap(settledPairing)
        let walletSecrets = await wallet.storedSecrets()
        let pairingKey = try XCTUnwrap(walletSecrets.keys[pairingTopic])

        do {
            try await wallet.pair(uri: WalletConnectURI(topic: pairingTopic, symKey: pairingKey))
            XCTFail("Paired twice")
        } catch WalletConnectClient.ClientError.pairingAlreadyActive {}

        // A topic the dApp chose at random, as the Swift and Kotlin SDKs do, is a valid pairing.
        let randomTopic = Hex.encode(try WalletConnectCrypto.randomKey())
        try await wallet.pair(uri: WalletConnectURI(topic: randomTopic, symKey: Hex.encode(try WalletConnectCrypto.randomKey())))
        try await waitUntil { relay.isSubscribed(randomTopic) }

        let symKey = try WalletConnectCrypto.randomKey()
        do {
            try await wallet.pair(uri: WalletConnectURI(
                topic: WalletConnectCrypto.topic(forSymmetricKey: symKey),
                symKey: Hex.encode(symKey),
                expiryTimestamp: UInt64(Date().timeIntervalSince1970) - 10
            ))
            XCTFail("Paired with an expired link")
        } catch WalletConnectClient.ClientError.pairingExpired {}
        await dapp.close()
    }

    func testApprovalMustGrantWhatTheProposalRequires() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        let polygon = Blockchain("eip155:137")!

        try await wallet.pair(uri: try await dapp.propose(required: .object([
            "eip155": .object([
                "chains": .array([.string("eip155:1"), .string("eip155:137")]),
                "methods": .array([.string("personal_sign")]),
                "events": .array([])
            ])
        ])))
        let proposal = try await events.waitForProposal()
        let proposedPairing = await dapp.pairingTopic
        let pairingTopic = try XCTUnwrap(proposedPairing)
        let published = relay.publishedMessages(on: pairingTopic).count

        // No account on eip155:137.
        do {
            _ = try await wallet.approve(proposalId: proposal.id, namespaces: grant)
            XCTFail("Approved without a required chain")
        } catch WalletConnectClient.ClientError.invalidNamespaces {}

        // An account under another namespace's key.
        let misplaced = ["polkadot": SessionNamespace(accounts: [Account(blockchain: polygon, address: evmAddress)!], methods: [], events: [])]
        do {
            _ = try await wallet.approve(proposalId: proposal.id, namespaces: misplaced)
            XCTFail("Approved a malformed grant")
        } catch WalletConnectClient.ClientError.invalidNamespaces {}
        XCTAssertEqual(relay.publishedMessages(on: pairingTopic).count, published)

        let full = ["eip155": SessionNamespace(
            chains: [ethereum, polygon],
            accounts: [Account(blockchain: ethereum, address: evmAddress)!, Account(blockchain: polygon, address: evmAddress)!],
            methods: ["personal_sign"],
            events: []
        )]
        _ = try await wallet.approve(proposalId: proposal.id, namespaces: full)
        guard case .response = try await dapp.proposalAnswer() else {
            return XCTFail("Refused")
        }
        await dapp.close()
    }

    func testProposalsItCannotReadOrSettleAreNotOffered() async throws {
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay)
        let events = EventRecorder(wallet)

        let unreadable: [[String: JSONValue]] = [
            ["requiredNamespaces": .string("everything")],
            ["optionalNamespaces": .object(["EIP155": .object(["methods": .array([]), "events": .array([])])])],
            ["sessionProperties": .object(["key": .int(1)])],
            ["relays": .array([.object(["data": .string("x")])])]
        ]
        for extra in unreadable {
            let dapp = TestDApp(relay: relay)
            try await wallet.pair(uri: try await dapp.propose(extra: extra))
            await dapp.close()
        }
        let badKey = TestDApp(relay: relay)
        try await wallet.pair(uri: try await badKey.propose(proposerPublicKey: "zz"))
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(events.proposals().isEmpty)

        // A proposer key that would give the all-zero secret is offered but can never be approved.
        let lowOrder = TestDApp(relay: relay)
        try await wallet.pair(uri: try await lowOrder.propose(proposerPublicKey: String(repeating: "0", count: 64)))
        let proposal = try await events.waitForProposal()
        do {
            _ = try await wallet.approve(proposalId: proposal.id, namespaces: grant)
            XCTFail("Approved a low-order key")
        } catch {
            // CryptoKit or the client's own all-zero check refuses it.
        }
        XCTAssertTrue(wallet.currentSessions.isEmpty)
        await badKey.close()
        await lowOrder.close()
    }
}

extension RPCResult {
    var errorCode: Int? {
        if case let .error(error) = self {
            return error.code
        }
        return nil
    }
}
