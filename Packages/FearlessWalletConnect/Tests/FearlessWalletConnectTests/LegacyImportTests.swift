import CryptoKit
import XCTest
@testable import FearlessWalletConnect

/// The user defaults and keychain of a device, in memory: the app group's and the app's own.
final class FakeLegacyStorage: LegacyWalletConnectStorage, @unchecked Sendable {
    private let lock = NSLock()
    var group: [String: Data] = [:]
    var standard: [String: Data] = [:]
    var groupKeychain: [String: Data] = [:]
    var defaultKeychain: [String: Data] = [:]

    func records(withPrefix prefix: String) -> [(key: String, value: Data)] {
        lock.lock()
        defer { lock.unlock() }
        var result = group.filter { $0.key.hasPrefix(prefix) }
        for (key, value) in standard where key.hasPrefix(prefix) && result[key] == nil {
            result[key] = value
        }
        return result.map { ($0.key, $0.value) }.sorted { $0.0 < $1.0 }
    }

    func value(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return group[key] ?? standard[key]
    }

    func keychainItem(account: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return groupKeychain[account] ?? defaultKeychain[account]
    }

    func removeRecords(keys: [String], keychainAccounts: [String]) {
        lock.lock()
        defer { lock.unlock() }
        for key in keys {
            group[key] = nil
            standard[key] = nil
        }
        for account in keychainAccounts {
            groupKeychain[account] = nil
            defaultKeychain[account] = nil
        }
    }
}

/// What an earlier SDK left for one session: its record, its keys, and the dApp's side of the key.
struct LegacySessionFixture {
    let topic: String
    let pairingTopic: String
    let symmetricKey: Data
    let selfPublicKey: String
    let selfPrivateKey: Data
    let record: Data

    var recordKey: String {
        LegacyWalletConnectImporter.sessionPrefix + topic
    }

    /// `WCSession` as the SDK's `CodableStore` wrote it with a default `JSONEncoder`; `reown` adds the fields
    /// Reown 1.8.0 writes.
    static func make(
        expiry: Date,
        pairingTopic: String,
        reown: Bool,
        dAppRole: Bool = false
    ) throws -> LegacySessionFixture {
        let selfKey = Curve25519.KeyAgreement.PrivateKey()
        let peerKey = Curve25519.KeyAgreement.PrivateKey()
        let symKey = try WalletConnectCrypto.deriveSymmetricKey(privateKey: selfKey, peerPublicKey: peerKey.publicKey.rawRepresentation)
        let topic = WalletConnectCrypto.topic(forSymmetricKey: symKey)
        let selfPublic = Hex.encode(selfKey.publicKey.rawRepresentation)
        let peerPublic = Hex.encode(peerKey.publicKey.rawRepresentation)

        var record: [String: Any] = [
            "topic": topic,
            "pairingTopic": pairingTopic,
            "relay": ["protocol": "irn"],
            "controller": ["publicKey": dAppRole ? peerPublic : selfPublic],
            "selfParticipant": [
                "publicKey": selfPublic,
                "metadata": [
                    "name": "Fearless wallet",
                    "description": "Defi wallet",
                    "url": "https://fearlesswallet.io",
                    "icons": ["https://fearlesswallet.io/icon.png"],
                    "redirect": ["native": "fearless://"]
                ]
            ],
            "peerParticipant": [
                "publicKey": peerPublic,
                "metadata": [
                    "name": "Continuity dApp",
                    "description": "Upgrade fixture",
                    "url": "https://dapp.example",
                    "icons": ["https://dapp.example/icon.png"],
                    "redirect": ["native": "dapp://", "universal": "https://dapp.example/wc"]
                ]
            ],
            "namespaces": [
                "eip155": [
                    "chains": ["eip155:1"],
                    "accounts": ["eip155:1:0xab16a96D359eC26a11e2C2b3d8f8B8942d5Bfcdb"],
                    "methods": ["eth_sendTransaction", "personal_sign"],
                    "events": ["accountsChanged", "chainChanged"]
                ],
                "polkadot": [
                    "accounts": ["polkadot:91b171bb158e2d3848fa23a9f1c25182:15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5"],
                    "methods": ["polkadot_signTransaction", "polkadot_signMessage"],
                    "events": []
                ]
            ],
            "sessionProperties": NSNull(),
            "acknowledged": true,
            "expiryDate": expiry.timeIntervalSinceReferenceDate,
            "timestamp": expiry.addingTimeInterval(-7 * 86400).timeIntervalSinceReferenceDate,
            "requiredNamespaces": [
                "eip155": ["chains": ["eip155:1"], "methods": ["personal_sign"], "events": ["chainChanged"]]
            ]
        ]
        if reown {
            record["scopedProperties"] = NSNull()
            record["transportType"] = ["relay": [String: String]()]
            record["verifyContext"] = ["origin": "https://dapp.example", "validation": "VALID", "verifyUrl": "https://verify.walletconnect.org"]
        }

        return LegacySessionFixture(
            topic: topic,
            pairingTopic: pairingTopic,
            symmetricKey: symKey,
            selfPublicKey: selfPublic,
            selfPrivateKey: selfKey.rawRepresentation,
            record: try JSONSerialization.data(withJSONObject: record)
        )
    }

    /// The SDK's keychain items: `AgreementKeys` (key, then the public key) under the topic, and the private key.
    var keychainItems: [String: Data] {
        [
            topic: symmetricKey + (Hex.decode(selfPublicKey) ?? Data()),
            selfPublicKey: selfPrivateKey
        ]
    }
}

struct LegacyPairingFixture {
    let topic: String
    let symmetricKey: Data
    let record: Data

    var recordKey: String {
        LegacyWalletConnectImporter.pairingPrefix + topic
    }

    /// The Swift SDKs chose pairing topics at random, not as the key's SHA-256.
    static func make(expiry: Date, reown: Bool) throws -> LegacyPairingFixture {
        let symKey = try WalletConnectCrypto.randomKey()
        let topic = Hex.encode(try WalletConnectCrypto.randomKey())
        var record: [String: Any] = [
            "topic": topic,
            "relay": ["protocol": "irn"],
            "expiryDate": expiry.timeIntervalSinceReferenceDate
        ]
        if reown {
            record["requestReceived"] = true
            record["methods"] = NSNull()
        } else {
            record["active"] = true
            record["requestReceived"] = false
            record["peerMetadata"] = ["name": "Continuity dApp", "description": "", "url": "https://dapp.example", "icons": []]
        }
        return LegacyPairingFixture(topic: topic, symmetricKey: symKey, record: try JSONSerialization.data(withJSONObject: record))
    }
}

final class LegacyImportTests: XCTestCase {
    private enum Layout {
        /// Fearless 4.2.x: Reown 1.8.0 in the app group.
        case reownInAppGroup
        /// Fearless 3.0.5 - 4.1.0: WalletConnectSwiftV2 in the app's own defaults and default keychain group.
        case walletConnectSwiftV2
    }

    private struct Device {
        let storage = FakeLegacyStorage()
        let live: LegacySessionFixture
        let expired: LegacySessionFixture
        let pairing: LegacyPairingFixture
        let clientSeed: Data
    }

    private func seed(_ layout: Layout, now: Date = Date()) throws -> Device {
        let pairing = try LegacyPairingFixture.make(expiry: now.addingTimeInterval(20 * 86400), reown: layout == .reownInAppGroup)
        let live = try LegacySessionFixture.make(
            expiry: now.addingTimeInterval(5 * 86400),
            pairingTopic: pairing.topic,
            reown: layout == .reownInAppGroup
        )
        let expired = try LegacySessionFixture.make(
            expiry: now.addingTimeInterval(-2 * 86400),
            pairingTopic: pairing.topic,
            reown: layout == .reownInAppGroup
        )
        let client = Curve25519.Signing.PrivateKey()
        let device = Device(live: live, expired: expired, pairing: pairing, clientSeed: client.rawRepresentation)

        var defaults: [String: Data] = [
            live.recordKey: live.record,
            expired.recordKey: expired.record,
            pairing.recordKey: pairing.record,
            LegacyWalletConnectImporter.clientPublicKeyKey: client.publicKey.rawRepresentation
        ]
        defaults[LegacyWalletConnectImporter.sessionPrefix + String(repeating: "e", count: 64)] = Data(#"{"topic":"#.utf8)
        var keychain = live.keychainItems.merging(expired.keychainItems) { first, _ in first }
        keychain[pairing.topic] = pairing.symmetricKey
        keychain[Hex.encode(Data(SHA256.hash(data: client.publicKey.rawRepresentation)))] = client.rawRepresentation

        switch layout {
        case .reownInAppGroup:
            device.storage.group = defaults
            device.storage.groupKeychain = keychain
        case .walletConnectSwiftV2:
            device.storage.standard = defaults
            device.storage.defaultKeychain = keychain
        }
        return device
    }

    func testEarlierSDKSessionsCarryOverWithTheirKeysAndRelayIdentity() async throws {
        for layout in [Layout.reownInAppGroup, .walletConnectSwiftV2] {
            let device = try seed(layout)
            let before = (device.storage.group, device.storage.standard, device.storage.groupKeychain, device.storage.defaultKeychain)
            let relay = FakeRelay()
            let wallet = try await makeWallet(relay: relay, legacy: device.storage)

            let sessions = wallet.currentSessions
            XCTAssertEqual(sessions.map(\.topic), [device.live.topic], "\(layout)")
            let session = try XCTUnwrap(sessions.first)
            XCTAssertEqual(session.peer.name, "Continuity dApp")
            XCTAssertEqual(session.peer.url, "https://dapp.example")
            XCTAssertEqual(session.pairingTopic, device.pairing.topic)
            XCTAssertEqual(Set(session.namespaces.keys), ["eip155", "polkadot"])
            XCTAssertEqual(session.requiredNamespaces["eip155"]?.chains, [ethereum])
            XCTAssertEqual(
                session.expiryDate.timeIntervalSince1970,
                Date().addingTimeInterval(5 * 86400).timeIntervalSince1970,
                accuracy: 5
            )

            let secrets = await wallet.storedSecrets()
            XCTAssertEqual(secrets.keys[device.live.topic], Hex.encode(device.live.symmetricKey))
            XCTAssertEqual(secrets.keys[device.pairing.topic], Hex.encode(device.pairing.symmetricKey))
            XCTAssertNil(secrets.keys[device.expired.topic])
            let identity = try await wallet.clientId()
            XCTAssertEqual(identity, try RelayAuth.clientId(seed: device.clientSeed))

            let state = await wallet.storedState()
            XCTAssertEqual(state.pairings.map(\.topic), [device.pairing.topic])
            XCTAssertEqual(state.pairings.first?.active, true)
            XCTAssertEqual(state.legacyImport?.sessions, 1)
            XCTAssertEqual(state.legacyImport?.clientIdentity, true)

            // The earlier records stay as they were, so the earlier version still finds them.
            XCTAssertEqual(device.storage.group, before.0)
            XCTAssertEqual(device.storage.standard, before.1)
            XCTAssertEqual(device.storage.groupKeychain, before.2)
            XCTAssertEqual(device.storage.defaultKeychain, before.3)

            // The wallet listens on the carried-over session and pairing.
            try await waitUntil { relay.isSubscribed(device.live.topic) && relay.isSubscribed(device.pairing.topic) }
            await wallet.stop()
        }
    }

    func testACarriedOverSessionKeepsAnsweringTheDAppAndEndsCleanly() async throws {
        let device = try seed(.reownInAppGroup)
        let relay = FakeRelay()
        let wallet = try await makeWallet(relay: relay, legacy: device.storage)
        let events = EventRecorder(wallet)

        // The dApp paired with the earlier build holds the same session key.
        let dapp = TestDApp(relay: relay)
        try await dapp.adoptSession(topic: device.live.topic, symmetricKey: device.live.symmetricKey)
        try await waitUntil { relay.subscriberCount(device.live.topic) == 2 }

        let id = try await dapp.sendRequest(
            method: "polkadot_signMessage",
            params: .object(["address": .string("15oF4uVJwmo4TdGW7VfQxNLavjCXviqxT9S1MgbjMNHr6Sp5"), "message": .string("0x01")]),
            chainId: "polkadot:91b171bb158e2d3848fa23a9f1c25182"
        )
        let request = try await events.waitForRequest()
        XCTAssertEqual(request.id, id)
        XCTAssertEqual(request.method, "polkadot_signMessage")
        try await wallet.respond(topic: device.live.topic, requestId: id, response: .error(JSONRPCError(code: 4001, message: "User rejected request")))
        let answer = try await dapp.response(to: id)
        XCTAssertEqual(answer.errorCode, 4001)

        try await dapp.send(.request(id: 5, method: "wc_sessionPing", params: .object([:])), on: device.live.topic, tag: 1114)
        let pong = try await dapp.response(to: 5)
        XCTAssertEqual(pong, .response(AnyCodable(json: .bool(true))))

        try await wallet.disconnect(topic: device.live.topic)
        _ = try await dapp.request(named: "wc_sessionDelete")

        // Its earlier records and keys go with it, so a downgrade cannot bring the ended session back.
        XCTAssertNil(device.storage.group[device.live.recordKey])
        XCTAssertNil(device.storage.groupKeychain[device.live.topic])
        XCTAssertNil(device.storage.groupKeychain[device.live.selfPublicKey])
        // Everything else stays.
        XCTAssertNotNil(device.storage.group[device.pairing.recordKey])
        XCTAssertNotNil(device.storage.groupKeychain[device.pairing.topic])
        await dapp.close()
    }

    func testRecordsThatCannotBeUsedAreLeftBehind() async throws {
        let now = Date()
        let storage = FakeLegacyStorage()
        let pairingTopic = String(repeating: "a", count: 64)
        let dAppRole = try LegacySessionFixture.make(expiry: now.addingTimeInterval(86400), pairingTopic: pairingTopic, reown: true, dAppRole: true)
        let missingKey = try LegacySessionFixture.make(expiry: now.addingTimeInterval(86400), pairingTopic: pairingTopic, reown: true)
        let wrongKey = try LegacySessionFixture.make(expiry: now.addingTimeInterval(86400), pairingTopic: pairingTopic, reown: true)
        let good = try LegacySessionFixture.make(expiry: now.addingTimeInterval(86400), pairingTopic: pairingTopic, reown: false)

        for fixture in [dAppRole, missingKey, wrongKey, good] {
            storage.group[fixture.recordKey] = fixture.record
        }
        storage.groupKeychain.merge(dAppRole.keychainItems) { first, _ in first }
        storage.groupKeychain[wrongKey.topic] = Data(repeating: 1, count: 64)
        storage.groupKeychain.merge(good.keychainItems) { first, _ in first }

        let wallet = try await makeWallet(relay: FakeRelay(), legacy: storage)
        XCTAssertEqual(wallet.currentSessions.map(\.topic), [good.topic])
        // No relay identity was found, so the client made its own.
        let state = await wallet.storedState()
        XCTAssertEqual(state.legacyImport?.clientIdentity, false)
        let ownIdentity = try await wallet.clientId()
        XCTAssertTrue(ownIdentity.hasPrefix("did:key:z6Mk"))
        await wallet.stop()
    }

    func testImportsOnlyWhatItDoesNotKnowAndNeverRevivesAnEndedSession() async throws {
        let device = try seed(.reownInAppGroup)
        let relay = FakeRelay()
        let store = InMemoryWalletConnectStore()
        let first = try await makeWallet(relay: relay, store: store, legacy: device.storage)
        let identity = try await first.clientId()
        try await first.disconnect(topic: device.live.topic)
        await first.stop()

        // The removal failed or a downgrade put the record back; another session was made in the earlier build.
        device.storage.group[device.live.recordKey] = device.live.record
        device.storage.groupKeychain.merge(device.live.keychainItems) { _, new in new }
        let newer = try LegacySessionFixture.make(expiry: Date().addingTimeInterval(6 * 86400), pairingTopic: device.pairing.topic, reown: true)
        device.storage.group[newer.recordKey] = newer.record
        device.storage.groupKeychain.merge(newer.keychainItems) { _, new in new }

        let second = try await makeWallet(relay: relay, store: store, legacy: device.storage)
        XCTAssertEqual(second.currentSessions.map(\.topic), [newer.topic])
        let secondIdentity = try await second.clientId()
        XCTAssertEqual(secondIdentity, identity)
        let state = await second.storedState()
        XCTAssertEqual(state.sessions.count, 1)
        XCTAssertEqual(state.pairings.count, 1)
        await second.stop()
    }

    func testSessionsWhoseKeysAreGoneAreDropped() async throws {
        let relay = FakeRelay()
        let store = InMemoryWalletConnectStore()
        let wallet = try await makeWallet(relay: relay, store: store)
        let events = EventRecorder(wallet)
        let dapp = TestDApp(relay: relay)
        _ = try await settle(wallet, dapp, events: events)
        await wallet.stop()
        await dapp.close()

        // A device restored from a backup has the record but not the keychain item, which never leaves the device.
        let restored = InMemoryWalletConnectStore(state: try store.loadState(), secrets: nil)
        let second = try await makeWallet(relay: FakeRelay(), store: restored)
        XCTAssertTrue(second.currentSessions.isEmpty)
        let state = await second.storedState()
        XCTAssertTrue(state.pairings.isEmpty)
        await second.stop()
    }
}
