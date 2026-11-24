import UIKit
import WebKit
import CoreData
import CryptoKit
import Foundation
import RobinHood
import SoraFoundation
import SoraKeystore
import TonSwift
import TweetNacl
import SQLite3
import XCTest
@testable import fearless

private let tonConnectNativePhrase = "cluster notice abandon frost gospel boring element situate click mix vague replace imitate garment useful crater resource dose tenant theme foam ancient phrase slight"

private func tonConnectTestSession(id: String = "legacy-session", clientId: String? = nil, type: String = "http") throws -> LegacyTonConnectSession {
    let walletPair = try NaclBox.keyPair(fromSecretKey: Data(repeating: 7, count: 32))
    let peerPair = try NaclBox.keyPair(fromSecretKey: Data(repeating: 9, count: 32))
    return LegacyTonConnectSession(
        identifier: id, walletId: "legacy-wallet", clientId: clientId ?? peerPair.publicKey.map { String(format: "%02x", $0) }.joined(),
        appUrl: URL(string: "https://example.org/app")!, name: "Original application", iconUrl: nil,
        publicKey: walletPair.publicKey, privateKey: walletPair.secretKey, connectionType: type
    )
}

final class LegacyTonConnectProtocolTests: XCTestCase {
    func testStoredSessionKeysDecryptOldPeerWithoutReplacement() throws {
        let session = try tonConnectTestSession()
        let peer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 9, count: 32))
        let nonce = Data(repeating: 1, count: 24)
        let message = Data(#"{"id":"1","method":"disconnect","params":[]}"#.utf8)
        let encrypted = try nonce + NaclBox.box(message: message, nonce: nonce, publicKey: session.publicKey, secretKey: peer.secretKey)
        XCTAssertEqual(try session.validated(), session)
        XCTAssertEqual(try session.decrypt(encrypted, from: session.clientId), message)
        let response = try session.encrypt(message)
        XCTAssertEqual(try NaclBox.open(message: Data(response.dropFirst(24)), nonce: Data(response.prefix(24)), publicKey: session.publicKey, secretKey: peer.secretKey), message)
        XCTAssertThrowsError(try session.decrypt(encrypted, from: String(repeating: "0", count: 64)))
        XCTAssertThrowsError(try session.decrypt(Data(repeating: 0, count: 39), from: session.clientId))
        var damaged = encrypted
        damaged[damaged.count - 1] ^= 1
        XCTAssertThrowsError(try session.decrypt(damaged, from: session.clientId))
    }

    func testInvalidStoredKeyBindingNeverRegeneratesSession() throws {
        let original = try tonConnectTestSession()
        let invalid = LegacyTonConnectSession(identifier: original.identifier, walletId: original.walletId, clientId: original.clientId,
                                              appUrl: original.appUrl, name: original.name, iconUrl: nil,
                                              publicKey: Data(repeating: 0, count: 32), privateKey: original.privateKey, connectionType: "http")
        XCTAssertThrowsError(try invalid.validated())
        XCTAssertEqual(invalid.privateKey, original.privateKey)
    }

    func testProofDigestMatchesIndependentByteOrderVector() throws {
        let address = try TonSwift.Address.parse("0:" + String(repeating: "11", count: 32))
        let digest = LegacyTonConnectProtocol.proofDigest(address: address, domain: "example.org", payload: "legacy-proof", timestamp: 1_720_000_000)
        XCTAssertEqual(digest.map { String(format: "%02x", $0) }.joined(), "9b3f53ec539f2a9cd4e047c84310abc11494d2272109b35cae7303b76144e9f9")
    }

    func testNativeAccountConnectionAndProofRetainExactAddressAndKey() throws {
        let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: tonConnectNativePhrase.components(separatedBy: " "))
        let address = try WalletV4R2(publicKey: pair.publicKey.data).address()
        let account = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(address), publicKey: pair.publicKey.data, contractVersion: "v4R2")
        let request = LegacyTonConnectConnectRequest(manifestUrl: URL(string: "https://example.org/manifest.json")!, items: [.init(name: "ton_addr", payload: nil), .init(name: "ton_proof", payload: "legacy-proof")])
        let manifest = LegacyTonConnectManifest(url: URL(string: "https://example.org/app")!, name: "Old application", iconUrl: nil)
        let response = try LegacyTonConnectProtocol.connectEvent(account: account, privateKey: pair.privateKey.data, network: "-239", request: request, manifest: manifest, timestamp: 1_720_000_000)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        let items = try XCTUnwrap(payload["items"] as? [[String: Any]])
        XCTAssertEqual((payload["device"] as? [String: Any])?["appName"] as? String, "Fearless")
        XCTAssertEqual(items[0]["address"] as? String, address.toRaw())
        XCTAssertEqual(items[0]["network"] as? String, "-239")
        XCTAssertNotNil(items[0]["walletStateInit"] as? String)
        let proof = try XCTUnwrap(items[1]["proof"] as? [String: Any])
        let signature = try XCTUnwrap((proof["signature"] as? String).flatMap { Data(base64Encoded: $0) })
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: pair.publicKey.data)
        XCTAssertTrue(publicKey.isValidSignature(signature, for: LegacyTonConnectProtocol.proofDigest(address: address, domain: "example.org", payload: "legacy-proof", timestamp: 1_720_000_000)))
        XCTAssertThrowsError(try LegacyTonConnectProtocol.connectEvent(account: account, privateKey: nil, network: "-239", request: request, manifest: manifest, timestamp: 1))
        let restore = LegacyTonConnectConnectRequest(manifestUrl: request.manifestUrl, items: [.init(name: "ton_addr", payload: nil)])
        XCTAssertNoThrow(try LegacyTonConnectProtocol.connectEvent(account: account, privateKey: nil, network: "-3", request: restore, manifest: manifest, timestamp: 1))
    }

    func testLinkValidationPreservesProtocolAndRejectsConflictingParameters() throws {
        let peer = try tonConnectTestSession().clientId
        let request = #"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#
        var parts = URLComponents(string: "tc://")!
        parts.queryItems = [.init(name: "v", value: "2"), .init(name: "id", value: peer), .init(name: "r", value: request)]
        let parsed = try LegacyTonConnectProtocol.parseLink(XCTUnwrap(parts.url))
        XCTAssertEqual(parsed.clientId, peer)
        XCTAssertEqual(parsed.request.items[0].name, "ton_addr")
        parts.queryItems?.append(.init(name: "id", value: peer))
        XCTAssertThrowsError(try LegacyTonConnectProtocol.parseLink(XCTUnwrap(parts.url)))
        XCTAssertNil(LegacyTonConnectProtocol.clientKey("zz" + String(repeating: "0", count: 62)))
        XCTAssertNil(LegacyTonConnectProtocol.origin(URL(string: "https://user:pass@example.org")!))
        XCTAssertEqual(LegacyTonConnectProtocol.origin(URL(string: "https://EXAMPLE.org:443/path")!), "https://example.org")
        XCTAssertThrowsError(try LegacyTonConnectManifest(url: URL(string: "https://example.org")!, name: "", iconUrl: nil).validated())
    }

    func testTransactionRequestBindsOriginalWalletNetworkExpiryAndLimits() throws {
        let sender = "0:" + String(repeating: "11", count: 32)
        var json: [String: Any] = ["valid_until": 100, "network": "-3", "from": sender, "messages": [["address": sender, "amount": "1"]]]
        var data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertEqual(try LegacyTonConnectTransactionParameters.decode(data, sender: sender, network: "-3", now: 99).messages.count, 1)
        XCTAssertThrowsError(try LegacyTonConnectTransactionParameters.decode(data, sender: sender, network: "-239", now: 99))
        XCTAssertThrowsError(try LegacyTonConnectTransactionParameters.decode(data, sender: sender, network: "-3", now: 100))
        XCTAssertThrowsError(try LegacyTonConnectTransactionParameters.decode(data, sender: "invalid", network: "-3", now: 1))
        json["messages"] = Array(repeating: ["address": sender, "amount": "1"], count: 5)
        data = try JSONSerialization.data(withJSONObject: json)
        XCTAssertThrowsError(try LegacyTonConnectTransactionParameters.decode(data, sender: sender, network: "-3", now: 99))
        let rpc = try LegacyTonConnectRPCRequest.decode(Data(#"{"id":"1","method":"sendTransaction","params":["{}"]}"#.utf8))
        XCTAssertEqual(rpc.id, "1")
        XCTAssertThrowsError(try LegacyTonConnectRPCRequest.decode(Data(#"{"id":"1","method":"unknown","params":[]}"#.utf8)))
        XCTAssertThrowsError(try LegacyTonConnectRPCRequest.decode(Data(repeating: 0, count: 65_537)))
        XCTAssertNoThrow(try LegacyTonConnectProtocol.response(id: "1", result: "boc"))
        XCTAssertNoThrow(try LegacyTonConnectProtocol.response(id: "1", errorCode: 300, message: "Declined"))
    }

    func testSSEParserHandlesMultipleEventsCommentsAndSplitInput() throws {
        var parser = LegacyTonConnectEventParser()
        var events: [LegacyTonConnectServerEvent] = []
        let stream = ": keepalive\r\n\r\nid: 42\r\nevent: message\r\ndata: {\"a\":1}\r\n\r\nid: 43\ndata: first\ndata: second\n\n"
        for byte in stream.utf8 { if let event = try parser.append(byte) { events.append(event) } }
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0].id, "42")
        XCTAssertEqual(String(data: events[1].data, encoding: .utf8), "first\nsecond")
        var oversized = LegacyTonConnectEventParser()
        XCTAssertThrowsError(try Array(repeating: UInt8(65), count: 100_001).forEach { _ = try oversized.append($0) })
    }

    func testBridgeEndpointPreservesOriginalBridgeAndEscapesCursor() throws {
        let base = URL(string: "https://bridge.example.org/bridge")!
        let url = try LegacyTonConnectBridgeTransport.endpoint(bridge: base, method: "events", query: [.init(name: "last_event_id", value: "42&x=1")])
        XCTAssertEqual(url.path, "/bridge/events")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems, [.init(name: "last_event_id", value: "42&x=1")])
        for text in ["http://bridge.example.org", "https://user:pass@bridge.example.org", "https://bridge.example.org?x=1", "https://bridge.example.org/%2e%2e"] {
            XCTAssertFalse(LegacyTonConnectBridgeTransport.validBridgeURL(URL(string: text)!))
        }
        let transport = LegacyTonConnectBridgeTransport()
        var redirected: URLRequest?
        transport.urlSession(URLSession.shared, task: URLSession.shared.dataTask(with: base), willPerformHTTPRedirection: HTTPURLResponse(url: base, statusCode: 302, httpVersion: nil, headerFields: nil)!, newRequest: URLRequest(url: base)) { redirected = $0 }
        XCTAssertNil(redirected)
    }
}

final class LegacyTonConnectReplyTests: XCTestCase {
    func testDurableReplySurvivesRestartAndRejectsReusedRPCId() throws {
        let keychain = TonConnectFixtureKeychain()
        keychain.values["old-secret"] = Data([1, 2, 3])
        let store = LegacyTonConnectReplyStore(keystore: keychain)
        let request = Data("original request".utf8)
        let response = Data("signed response".utf8)
        XCTAssertNil(try store.reply(sessionId: "session", requestId: "1", request: request))
        try store.save(response: response, messageHashHex: "message-hash", sessionId: "session", requestId: "1", request: request)
        let reopened = LegacyTonConnectReplyStore(keystore: keychain)
        XCTAssertEqual(try reopened.reply(sessionId: "session", requestId: "1", request: request)?.response, response)
        XCTAssertEqual(try reopened.reply(sessionId: "session", requestId: "1", request: request)?.messageHashHex, "message-hash")
        XCTAssertThrowsError(try reopened.reply(sessionId: "session", requestId: "1", request: Data("different".utf8)))
        XCTAssertThrowsError(try reopened.save(response: Data(), sessionId: "session", requestId: "1", request: request))
        try reopened.save(response: response, messageHashHex: "message-hash", sessionId: "session", requestId: "1", request: request)
        XCTAssertEqual(keychain.values["old-secret"], Data([1, 2, 3]))
    }

    func testReplyWriteFailureNeverAppearsCompleteAndCanRetry() throws {
        let keychain = TonConnectFixtureKeychain()
        let store = LegacyTonConnectReplyStore(keystore: keychain)
        keychain.failWrites = true
        XCTAssertThrowsError(try store.save(response: Data([3]), sessionId: "session", requestId: "1", request: Data([4])))
        XCTAssertNil(try store.reply(sessionId: "session", requestId: "1", request: Data([4])))
        keychain.failWrites = false
        try store.save(response: Data([3]), sessionId: "session", requestId: "1", request: Data([4]))
        XCTAssertEqual(try store.reply(sessionId: "session", requestId: "1", request: Data([4]))?.response, Data([3]))
    }

    func testContextBindsOriginalNetworkBridgeAndAllowsOnlyCursorUpdate() throws {
        let keychain = TonConnectFixtureKeychain()
        let store = LegacyTonConnectReplyStore(keystore: keychain)
        XCTAssertNil(try store.context(sessionId: "session"))
        var context = LegacyTonConnectSessionContext(bridgeURL: URL(string: "https://bridge.example.org/bridge")!, network: "-3", lastEventId: "41")
        try store.save(context: context, sessionId: "session")
        context.lastEventId = "42"
        try store.save(context: context, sessionId: "session")
        XCTAssertEqual(try LegacyTonConnectReplyStore(keystore: keychain).context(sessionId: "session"), context)
        XCTAssertThrowsError(try store.save(context: .init(bridgeURL: context.bridgeURL, network: "-239", lastEventId: "43"), sessionId: "session"))
        XCTAssertThrowsError(try store.save(context: .init(bridgeURL: URL(string: "https://different.example")!, network: "-3", lastEventId: nil), sessionId: "session"))
    }
}

private final class TonConnectFixtureKeychain: KeystoreProtocol {
    var values: [String: Data] = [:]
    var failWrites = false
    func addKey(_ key: Data, with identifier: String) throws {
        if failWrites { throw KeystoreError.unexpectedFail }
        guard values[identifier] == nil else { throw KeystoreError.duplicatedItem }
        values[identifier] = key
    }
    func updateKey(_ key: Data, with identifier: String) throws {
        if failWrites { throw KeystoreError.unexpectedFail }
        values[identifier] = key
    }
    func fetchKey(for identifier: String) throws -> Data {
        guard let value = values[identifier] else { throw KeystoreError.noKeyFound }
        return value
    }
    func checkKey(for identifier: String) throws -> Bool { values[identifier] != nil }
    func deleteKey(for identifier: String) throws { values.removeValue(forKey: identifier) }
}

/// Passes everything to `keys` and records each secret read.
private final class TonConnectSecretReadSpy: KeystoreProtocol {
    private let keys: KeystoreProtocol
    private(set) var reads: [String] = []
    init(_ keys: KeystoreProtocol) { self.keys = keys }
    func addKey(_ key: Data, with identifier: String) throws { try keys.addKey(key, with: identifier) }
    func updateKey(_ key: Data, with identifier: String) throws { try keys.updateKey(key, with: identifier) }
    func fetchKey(for identifier: String) throws -> Data {
        reads.append(identifier)
        return try keys.fetchKey(for: identifier)
    }
    func checkKey(for identifier: String) throws -> Bool { try keys.checkKey(for: identifier) }
    func deleteKey(for identifier: String) throws { try keys.deleteKey(for: identifier) }
}

private func withoutKeyColumn(_ row: [String: Data]) -> [String: Data] {
    row.filter { $0.key != "privateKey" }
}

private final class TonConnectFakeSessionKeys: LegacyTonConnectSessionKeyStoring {
    private let guardLock = NSLock()
    private var storage: [String: Data] = [:]
    private var inFlight = 0
    private var sawOverlap = false
    var failSaves: OSStatus?
    var failLoads: OSStatus?
    var failDeletes: OSStatus?
    var corruptReads = false
    /// Widens the window in which two store operations could overlap.
    var callDelay: useconds_t = 0
    private(set) var saveCount = 0

    var items: [String: Data] {
        get { guardLock.lock(); defer { guardLock.unlock() }; return storage }
        set { guardLock.lock(); storage = newValue; guardLock.unlock() }
    }

    var overlapped: Bool {
        guardLock.lock(); defer { guardLock.unlock() }
        return sawOverlap
    }

    private func enter() {
        guardLock.lock()
        inFlight += 1
        if inFlight > 1 { sawOverlap = true }
        guardLock.unlock()
        if callDelay > 0 { usleep(callDelay) }
    }

    private func leave() {
        guardLock.lock()
        inFlight -= 1
        guardLock.unlock()
    }

    func saveKey(_ key: Data, reference: String) throws {
        enter(); defer { leave() }
        if let status = failSaves { throw LegacyTonConnectSessionKeyError.keychainUnavailable(status) }
        guardLock.lock(); defer { guardLock.unlock() }
        // As the Keychain class does: a stored value is never replaced; the same bytes count as saved.
        if let existing = storage[reference], existing != key {
            throw LegacyTonConnectSessionKeyError.existingKeyDiffers
        }
        storage[reference] = key
        saveCount += 1
    }

    func loadKey(reference: String) throws -> Data? {
        enter(); defer { leave() }
        if let status = failLoads { throw LegacyTonConnectSessionKeyError.keychainUnavailable(status) }
        guard let value = items[reference] else { return nil }
        guard corruptReads else { return value }
        var corrupted = value
        corrupted[corrupted.startIndex] ^= 0xFF
        return corrupted
    }

    func deleteKey(reference: String) throws {
        enter(); defer { leave() }
        if let status = failDeletes { throw LegacyTonConnectSessionKeyError.keychainUnavailable(status) }
        guardLock.lock()
        storage.removeValue(forKey: reference)
        guardLock.unlock()
    }

    private var retiredReferences: Set<String> = []
    var failRetires: OSStatus?
    var retired: Set<String> {
        guardLock.lock(); defer { guardLock.unlock() }
        return retiredReferences
    }

    func retire(reference: String) throws {
        if let status = failRetires { throw LegacyTonConnectSessionKeyError.keychainUnavailable(status) }
        guardLock.lock()
        retiredReferences.insert(reference)
        guardLock.unlock()
    }

    var failRetiredLookups: OSStatus?

    func isRetired(reference: String) throws -> Bool {
        if let status = failRetiredLookups { throw LegacyTonConnectSessionKeyError.keychainUnavailable(status) }
        return retired.contains(reference)
    }
}

private final class TonConnectGatedSessionStore: LegacyTonConnectSessionStoring {
    private let lock = NSLock()
    private var waiter: CheckedContinuation<Void, Error>?
    private var callCount = 0
    let values: [LegacyTonConnectSession]

    init(values: [LegacyTonConnectSession]) {
        self.values = values
    }

    var calls: Int { lock.lock(); defer { lock.unlock() }; return callCount }

    func waitForCaller() async throws {
        for _ in 0 ..< 200 {
            lock.lock()
            let waiting = waiter != nil
            lock.unlock()
            if waiting { return }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("start() never read the sessions")
    }

    func release(throwing: Bool) {
        lock.lock()
        let continuation = waiter
        waiter = nil
        lock.unlock()
        if throwing {
            continuation?.resume(throwing: LegacyTonConnectError.invalidSession)
        } else {
            continuation?.resume()
        }
    }

    func sessions() async throws -> [LegacyTonConnectSession] {
        lock.lock()
        callCount += 1
        let first = callCount == 1
        lock.unlock()
        if first {
            try await withCheckedThrowingContinuation { continuation in
                lock.lock()
                waiter = continuation
                lock.unlock()
            }
        }
        return values
    }

    func sessionsToReconnect() async throws -> [LegacyTonConnectSession] { [] }
    func finishReconnectOffer(for _: [LegacyTonConnectSession]) async throws {}
    func save(_: LegacyTonConnectSession) async throws {}
    func remove(_: LegacyTonConnectSession) async throws {}
    func bridgeURL(network _: String) async throws -> URL { URL(string: "https://bridge.example.org/bridge")! }
}

private final class TonConnectFlakySessionStore: LegacyTonConnectSessionStoring {
    private let lock = NSLock()
    private var failures: Int
    private var calls = 0
    let values: [LegacyTonConnectSession]

    init(failures: Int, values: [LegacyTonConnectSession]) {
        self.failures = failures
        self.values = values
    }

    var sessionCalls: Int { lock.lock(); defer { lock.unlock() }; return calls }

    func sessions() async throws -> [LegacyTonConnectSession] {
        lock.lock(); defer { lock.unlock() }
        calls += 1
        if failures > 0 {
            failures -= 1
            throw LegacyTonConnectError.invalidSession
        }
        return values
    }

    func sessionsToReconnect() async throws -> [LegacyTonConnectSession] { [] }
    func finishReconnectOffer(for _: [LegacyTonConnectSession]) async throws {}
    func save(_: LegacyTonConnectSession) async throws {}
    func remove(_: LegacyTonConnectSession) async throws {}
    func bridgeURL(network _: String) async throws -> URL { URL(string: "https://bridge.example.org/bridge")! }
}

final class LegacyTonConnectStoreTests: XCTestCase {
    func testReleasedSessionsReloadWithOriginalKeysAndMissingTypeRewritingOnlyTheKeyColumn() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("legacy.sqlite")
        let fixture = try TonConnectFixtureCoreDataService(url: file)
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http")
        let js = try tonConnectTestSession(id: "old-js", clientId: UUID().uuidString, type: "js")
        try fixture.insert(http, missingType: true)
        try fixture.insert(js, missingType: true)
        var malformed = try fixture.snapshot()
        XCTAssertEqual(malformed.count, 2)
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let sessions = try await store.sessions()
        XCTAssertEqual(Set(sessions.map(\.identifier)), [http.identifier, js.identifier])
        XCTAssertEqual(sessions.first(where: { $0.identifier == http.identifier })?.connectionType, "http")
        XCTAssertEqual(sessions.first(where: { $0.identifier == js.identifier })?.connectionType, "js")
        XCTAssertEqual(sessions.first(where: { $0.identifier == http.identifier })?.privateKey, http.privateKey)
        // Only the key column changes: every other value, the missing type included, stays as released.
        XCTAssertEqual(try fixture.snapshot().map(withoutKeyColumn), malformed.map(withoutKeyColumn))
        try fixture.close()
        let reopened = try TonConnectFixtureCoreDataService(url: file)
        let restored = try await LegacyTonConnectStore(service: reopened, keys: keys).sessions()
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored.first(where: { $0.identifier == js.identifier })?.publicKey, js.publicKey)
        XCTAssertEqual(restored.first(where: { $0.identifier == js.identifier })?.privateKey, js.privateKey)
        malformed = try reopened.snapshot()
        XCTAssertFalse(malformed.contains { $0["connectionType"] != nil })
        try reopened.close()
    }

    func testSessionSaveConflictAndDisconnectPreserveOtherLegacyRows() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let original = try tonConnectTestSession()
        try await store.save(original)
        try await store.save(original)
        let second = try tonConnectTestSession(id: "second")
        try await store.save(second)
        let snapshot = try fixture.snapshot()
        let conflict = LegacyTonConnectSession(identifier: original.identifier, walletId: original.walletId,
                                               clientId: original.clientId, appUrl: original.appUrl, name: "Changed name",
                                               iconUrl: nil, publicKey: original.publicKey, privateKey: original.privateKey, connectionType: "http")
        do { try await store.save(conflict); XCTFail("Must not overwrite an original session") } catch {}
        XCTAssertEqual(try fixture.snapshot(), snapshot)
        try await store.remove(original)
        let remaining = try await store.sessions()
        XCTAssertEqual(remaining, [second])
        XCTAssertNil(keys.items[LegacyTonConnectSessionKeyReference(identifier: original.identifier, publicKey: original.publicKey).account],
                     "A disconnected session's key goes with its row")
        XCTAssertEqual(keys.items.count, 1)
        try await store.remove(original)
    }

    func testInvalidSessionDoesNotHideOtherSessionsAndBridgeUsesRetainedChain() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let original = try tonConnectTestSession()
        try fixture.insert(original)
        let invalid = LegacyTonConnectSession(identifier: "invalid", walletId: original.walletId, clientId: "unknown", appUrl: original.appUrl, name: original.name,
                                              iconUrl: nil, publicKey: Data(repeating: 0, count: 32), privateKey: original.privateKey, connectionType: "future")
        try fixture.insert(invalid)
        let store = LegacyTonConnectStore(service: fixture, keys: TonConnectFakeSessionKeys())
        let sessions = try await store.sessions()
        XCTAssertEqual(sessions, [original])
        XCTAssertEqual(try fixture.snapshot().count, 2)
        let bridge = URL(string: "https://bridge.example.org/bridge")!
        try fixture.insertBridge(network: "-3", url: bridge)
        let resolved = try await store.bridgeURL(network: "-3")
        XCTAssertEqual(resolved, bridge)
        do { _ = try await store.bridgeURL(network: "-239"); XCTFail("Do not replace a missing bridge") } catch {}
    }
}

final class LegacyTonConnectServiceTests: XCTestCase {
    func testDurableResponseIsCommittedBeforeAcknowledgementAndReusedAfterRestart() async throws {
        let session = try tonConnectTestSession()
        let storage = TonConnectFakeSessionStore(values: [session])
        let keychain = TonConnectFixtureKeychain()
        let replies = LegacyTonConnectReplyStore(keystore: keychain)
        let service = LegacyTonConnectService(store: storage, replies: replies, transport: TonConnectFakeTransport())
        let handler = TonConnectFakeHandler()
        handler.onAcknowledge = { XCTAssertFalse(keychain.values.isEmpty) }
        await service.set(handler: handler)
        let request = Data(#"{"id":"1","method":"sendTransaction","params":["{}"]}"#.utf8)
        let first = try await service.handle(request, session: session, network: "-239")
        XCTAssertEqual(first, handler.response)
        XCTAssertEqual(handler.processCount, 1)
        XCTAssertEqual(handler.acknowledgeCount, 1)
        let restarted = LegacyTonConnectService(store: storage, replies: LegacyTonConnectReplyStore(keystore: keychain), transport: TonConnectFakeTransport())
        await restarted.set(handler: handler)
        let replay = try await restarted.handle(request, session: session, network: "-239")
        XCTAssertEqual(replay, first)
        XCTAssertEqual(handler.processCount, 1)
        XCTAssertEqual(handler.acknowledgeCount, 2)
        let changed = Data(#"{"id":"1","method":"sendTransaction","params":["changed"]}"#.utf8)
        do { _ = try await restarted.handle(changed, session: session, network: "-239"); XCTFail("Reused id must be rejected") } catch {}
        XCTAssertEqual(handler.processCount, 1)
    }

    func testFailedReplyCommitRetainsTransferJournalAndCanRetry() async throws {
        let session = try tonConnectTestSession()
        let keychain = TonConnectFixtureKeychain()
        let handler = TonConnectFakeHandler()
        let service = LegacyTonConnectService(store: TonConnectFakeSessionStore(values: [session]), replies: LegacyTonConnectReplyStore(keystore: keychain), transport: TonConnectFakeTransport())
        await service.set(handler: handler)
        let request = Data(#"{"id":"1","method":"sendTransaction","params":["{}"]}"#.utf8)
        keychain.failWrites = true
        do { _ = try await service.handle(request, session: session, network: "-239"); XCTFail("Commit must fail") } catch {}
        XCTAssertEqual(handler.acknowledgeCount, 0)
        keychain.failWrites = false
        _ = try await service.handle(request, session: session, network: "-239")
        XCTAssertEqual(handler.acknowledgeCount, 1)
    }

    func testRestartAfterReplyCommitBeforeJournalAcknowledgementDoesNotProcessAgain() async throws {
        let session = try tonConnectTestSession()
        let keychain = TonConnectFixtureKeychain()
        let handler = TonConnectFakeHandler()
        handler.failAcknowledge = true
        let storage = TonConnectFakeSessionStore(values: [session])
        let service = LegacyTonConnectService(store: storage, replies: LegacyTonConnectReplyStore(keystore: keychain), transport: TonConnectFakeTransport())
        await service.set(handler: handler)
        let request = Data(#"{"id":"1","method":"sendTransaction","params":["{}"]}"#.utf8)
        do { _ = try await service.handle(request, session: session, network: "-239"); XCTFail("Acknowledgement injected failure") } catch {}
        handler.failAcknowledge = false
        let restarted = LegacyTonConnectService(store: storage, replies: LegacyTonConnectReplyStore(keystore: keychain), transport: TonConnectFakeTransport())
        await restarted.set(handler: handler)
        _ = try await restarted.handle(request, session: session, network: "-239")
        XCTAssertEqual(handler.processCount, 1)
        XCTAssertEqual(handler.acknowledgeCount, 2)
    }

    func testOfflineSessionStartDoesNotBlockWalletAndRetainsSessionForRetry() async throws {
        let session = try tonConnectTestSession()
        let storage = TonConnectFakeSessionStore(values: [session])
        let transport = TonConnectFakeTransport()
        let started = expectation(description: "Optional bridge startup")
        transport.onListen = { started.fulfill() }
        let service = LegacyTonConnectService(store: storage, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()), transport: transport, legacyEventId: { "40" })
        await service.start(selectedNetwork: "-239")
        await fulfillment(of: [started], timeout: 2)
        await service.stop()
        XCTAssertEqual(storage.values, [session])
        let stored = try await service.sessions(walletId: session.walletId)
        XCTAssertEqual(stored, [session])
        let context = try await service.context(for: session, selectedNetwork: "-3")
        XCTAssertEqual(context.network, "-239")
        XCTAssertEqual(context.lastEventId, "40")
        try await service.save(session: session, context: context)
        try await service.disconnect(session)
        XCTAssertTrue(storage.values.isEmpty)
    }

    func testAuthenticatedDisconnectAndRemovedSessionNeverReachSigningHandler() async throws {
        let session = try tonConnectTestSession()
        let storage = TonConnectFakeSessionStore(values: [session])
        let handler = TonConnectFakeHandler()
        let service = LegacyTonConnectService(store: storage, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()), transport: TonConnectFakeTransport())
        await service.set(handler: handler)
        _ = try await service.handle(Data(#"{"id":"1","method":"disconnect","params":[]}"#.utf8), session: session, network: "-239")
        XCTAssertTrue(storage.values.isEmpty)
        XCTAssertEqual(handler.processCount, 0)
        do { _ = try await service.handle(Data(#"{"id":"2","method":"sendTransaction","params":["{}"]}"#.utf8), session: session, network: "-239"); XCTFail("Removed session cannot sign") } catch {}
    }
}

private final class TonConnectFakeSessionStore: LegacyTonConnectSessionStoring {
    var values: [LegacyTonConnectSession]
    /// Sessions waiting for an answer to the offer to reconnect.
    var waiting: [LegacyTonConnectSession] = []
    /// Reads fail as with an unreadable Keychain.
    var failReads = false
    /// The next read waits for `releaseRead()`, then fails.
    private let readLock = NSLock()
    private var holdsNextRead = false
    private var heldRead: CheckedContinuation<Void, Never>?
    /// Signalled as a held read fails, from the store's own thread.
    let heldReadFailed = DispatchSemaphore(value: 0)
    /// A disconnect removes the session, then throws this (as one recorded but not finished).
    var removalError: Error?
    init(values: [LegacyTonConnectSession]) { self.values = values }
    func holdNextReadAndFailIt() {
        readLock.lock(); holdsNextRead = true; readLock.unlock()
    }
    var isHoldingRead: Bool { readLock.lock(); defer { readLock.unlock() }; return heldRead != nil }
    func releaseRead() {
        readLock.lock()
        let held = heldRead
        heldRead = nil
        readLock.unlock()
        held?.resume()
    }
    func sessions() async throws -> [LegacyTonConnectSession] {
        readLock.lock()
        let hold = holdsNextRead
        holdsNextRead = false
        readLock.unlock()
        if hold {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                readLock.lock(); heldRead = continuation; readLock.unlock()
            }
            heldReadFailed.signal()
            throw LegacyTonConnectError.invalidSession
        }
        if failReads { throw LegacyTonConnectError.invalidSession }
        return values
    }
    func sessionsToReconnect() async throws -> [LegacyTonConnectSession] { waiting.filter { values.contains($0) } }
    func finishReconnectOffer(for sessions: [LegacyTonConnectSession]) async throws { waiting.removeAll { sessions.contains($0) } }
    func save(_ session: LegacyTonConnectSession) async throws { if !values.contains(session) { values.append(session) } }
    func remove(_ session: LegacyTonConnectSession) async throws {
        values.removeAll { $0 == session }
        if let removalError { throw removalError }
    }
    func bridgeURL(network _: String) async throws -> URL { URL(string: "https://bridge.example.org/bridge")! }
}

private final class TonConnectFakeTransport: LegacyTonConnectBridgeTransporting {
    var onListen: (() -> Void)?
    private(set) var manifestCalls = 0
    private let sentLock = NSLock()
    private var sentValues: [(Data, LegacyTonConnectSession, URL, String)] = []
    /// Sends can arrive from concurrent tasks (disconnect notices go out together).
    var sent: [(Data, LegacyTonConnectSession, URL, String)] {
        get { sentLock.lock(); defer { sentLock.unlock() }; return sentValues }
        set { sentLock.lock(); sentValues = newValue; sentLock.unlock() }
    }
    var manifestValue: LegacyTonConnectManifest?
    func manifest(at url: URL) async throws -> LegacyTonConnectManifest {
        manifestCalls += 1
        return manifestValue ?? .init(url: url, name: "Fixture", iconUrl: nil)
    }
    var failSends = false
    func send(_ data: Data, session: LegacyTonConnectSession, bridge: URL, topic: String) async throws {
        if failSends { throw URLError(.notConnectedToInternet) }
        sentLock.lock()
        sentValues.append((data, session, bridge, topic))
        sentLock.unlock()
    }
    func listen(session _: LegacyTonConnectSession, context _: LegacyTonConnectSessionContext, receive _: @escaping (Data, String?) async throws -> Void) async throws {
        onListen?()
        throw URLError(.notConnectedToInternet)
    }
}

private final class TonConnectFakeHandler: LegacyTonConnectRequestHandling {
    let response = Data(#"{"id":"1","result":"signed-boc"}"#.utf8)
    var processCount = 0
    var acknowledgeCount = 0
    var failAcknowledge = false
    var processError: Error?
    var onAcknowledge: (() -> Void)?
    func process(session _: LegacyTonConnectSession, network _: String, request _: LegacyTonConnectRPCRequest) async throws -> LegacyTonConnectRPCOutcome {
        processCount += 1
        if let processError { throw processError }
        return .init(response: response, messageHashHex: String(repeating: "1", count: 64))
    }
    func acknowledge(session _: LegacyTonConnectSession, network _: String, request _: LegacyTonConnectRPCRequest, messageHashHex _: String) async throws {
        acknowledgeCount += 1
        onAcknowledge?()
        if failAcknowledge { throw KeystoreError.unexpectedFail }
    }
}

private final class TonConnectFixtureCoreDataService: CoreDataServiceProtocol {
    let configuration: CoreDataServiceConfigurationProtocol
    let context: NSManagedObjectContext

    init(url: URL? = nil) throws {
        let modelURL = try XCTUnwrap(Bundle.main.url(forResource: "SubstrateDataModel", withExtension: "momd"))
        configuration = CoreDataServiceConfiguration(modelURL: modelURL, storageType: .inMemory)
        let model = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelURL)?.copy() as? NSManagedObjectModel)
        model.entities.forEach { $0.managedObjectClassName = NSStringFromClass(NSManagedObject.self) }
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
        try coordinator.addPersistentStore(ofType: url == nil ? NSInMemoryStoreType : NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
    }

    func performAsync(block: @escaping CoreDataContextInvocationBlock) { context.perform { block(self.context, nil) } }
    func close() throws {
        try context.performAndWait {
            context.reset()
            guard let coordinator = context.persistentStoreCoordinator else { return }
            for store in coordinator.persistentStores { try coordinator.remove(store) }
        }
    }
    func drop() throws { try close() }

    func insert(_ session: LegacyTonConnectSession, missingType: Bool = false) throws {
        try context.performAndWait {
            let row = NSEntityDescription.insertNewObject(forEntityName: "CDTonConnectedApp", into: context)
            let values: [String: Any] = ["identifier": session.identifier, "walletId": session.walletId, "clientId": session.clientId,
                                       "appUrl": session.appUrl, "name": session.name, "publicKey": session.publicKey, "privateKey": session.privateKey]
            values.forEach { row.setValue($0.value, forKey: $0.key) }
            row.setValue(missingType ? nil : session.connectionType, forKey: "connectionType")
            try context.save()
        }
    }

    func insertRaw(_ session: LegacyTonConnectSession, privateKeyColumn: Data) throws {
        try context.performAndWait {
            let row = NSEntityDescription.insertNewObject(forEntityName: "CDTonConnectedApp", into: context)
            let values: [String: Any] = ["identifier": session.identifier, "walletId": session.walletId, "clientId": session.clientId,
                                         "appUrl": session.appUrl, "name": session.name, "publicKey": session.publicKey,
                                         "privateKey": privateKeyColumn, "connectionType": session.connectionType]
            values.forEach { row.setValue($0.value, forKey: $0.key) }
            try context.save()
        }
    }

    func insertBridge(network: String, url: URL) throws {
        try context.performAndWait {
            let row = NSEntityDescription.insertNewObject(forEntityName: "CDChain", into: context)
            for (name, attribute) in row.entity.attributesByName where !attribute.isOptional && row.value(forKey: name) == nil {
                if attribute.attributeType == .stringAttributeType { row.setValue("Fixture", forKey: name) }
                if attribute.attributeType == .booleanAttributeType { row.setValue(false, forKey: name) }
            }
            row.setValue(network, forKey: "chainId")
            row.setValue(url, forKey: "tonBridgeUrl")
            try context.save()
        }
    }

    func snapshot() throws -> [[String: Data]] {
        try context.performAndWait {
            context.reset()
            let rows = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "CDTonConnectedApp"))
            return rows.map { row in
                var result: [String: Data] = [:]
                for key in ["identifier", "walletId", "clientId", "name", "connectionType"] {
                    if let string = row.value(forKey: key) as? String { result[key] = Data(string.utf8) }
                }
                for key in ["publicKey", "privateKey"] { result[key] = row.value(forKey: key) as? Data }
                return result
            }.sorted { ($0["identifier"] ?? Data()).lexicographicallyPrecedes($1["identifier"] ?? Data()) }
        }
    }
}

final class LegacyTonConnectBridgeTransportTests: XCTestCase {
    override func tearDown() {
        TonConnectFixtureURLProtocol.handler = nil
        super.tearDown()
    }

    private func transport() -> LegacyTonConnectBridgeTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [TonConnectFixtureURLProtocol.self]
        return LegacyTonConnectBridgeTransport(configuration: configuration)
    }

    func testManifestAllowsHTTPSCDNAndReturnsValidatedApplicationIdentity() async throws {
        TonConnectFixtureURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "example.org")
            return (200, "application/json", Data(#"{"url":"https://example.org/app","name":"Original application"}"#.utf8))
        }
        let manifest = try await transport().manifest(at: URL(string: "https://example.org/manifest.json")!)
        XCTAssertEqual(manifest.name, "Original application")
        TonConnectFixtureURLProtocol.handler = { _ in
            (200, "application/json", Data(#"{"url":"https://other.example/app","name":"CDN application"}"#.utf8))
        }
        let cdnManifest = try await transport().manifest(at: URL(string: "https://example.org/manifest.json")!)
        XCTAssertEqual(cdnManifest.url.host, "other.example")
        TonConnectFixtureURLProtocol.handler = { _ in
            (200, "application/json", Data(#"{"url":"http://other.example/app","name":"Insecure application"}"#.utf8))
        }
        do { _ = try await transport().manifest(at: URL(string: "https://example.org/manifest.json")!); XCTFail("Insecure application must fail") } catch {}
        do { _ = try await transport().manifest(at: URL(string: "http://example.org/manifest.json")!); XCTFail("Insecure manifest must fail") } catch {}
        TonConnectFixtureURLProtocol.handler = { _ in (200, "application/json", Data(repeating: 65, count: 32_769)) }
        do { _ = try await transport().manifest(at: URL(string: "https://example.org/manifest.json")!); XCTFail("Oversized manifest must fail") } catch {}
    }

    func testBridgeResponseUsesStoredSessionKeyAndOriginalPeer() async throws {
        let session = try tonConnectTestSession()
        let expected = Data(#"{"id":"42","result":"boc"}"#.utf8)
        let received = expectation(description: "Encrypted bridge reply")
        TonConnectFixtureURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, "/bridge/message")
            let query = URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
            XCTAssertTrue(query.contains(.init(name: "to", value: session.clientId)))
            let body = try TonConnectFixtureURLProtocol.body(request)
            let ciphertext = try XCTUnwrap(String(data: body, encoding: .utf8).flatMap { Data(base64Encoded: $0) })
            let peer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 9, count: 32))
            let decrypted = try NaclBox.open(message: Data(ciphertext.dropFirst(24)), nonce: Data(ciphertext.prefix(24)), publicKey: session.publicKey, secretKey: peer.secretKey)
            XCTAssertEqual(decrypted, expected)
            received.fulfill()
            return (200, "application/json", Data(#"{"status_code":200}"#.utf8))
        }
        try await transport().send(expected, session: session, bridge: URL(string: "https://bridge.example.org/bridge")!, topic: "sendTransaction")
        await fulfillment(of: [received], timeout: 2)
    }

    func testBridgeReceivesEveryAuthenticatedEventAndIgnoresUntrustedEnvelope() async throws {
        let session = try tonConnectTestSession()
        let peer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 9, count: 32))
        let message = Data(#"{"id":"1","method":"disconnect","params":[]}"#.utf8)
        let nonce = Data(repeating: 2, count: 24)
        let encrypted = try nonce + NaclBox.box(message: message, nonce: nonce, publicKey: session.publicKey, secretKey: peer.secretKey)
        let envelope = try JSONSerialization.data(withJSONObject: ["from": session.clientId, "message": encrypted.base64EncodedString()])
        let valid = String(data: envelope, encoding: .utf8)!
        let stream = "id: 1\ndata: {\"from\":\"untrusted\",\"message\":\"invalid\"}\n\nid: 42\ndata: \(valid)\n\nid: 43\ndata: \(valid)\n\n"
        TonConnectFixtureURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/bridge/events")
            XCTAssertTrue(request.url?.query?.contains("last_event_id=41") == true)
            return (200, "text/event-stream", Data(stream.utf8))
        }
        var ids: [String] = []
        try await transport().listen(session: session, context: .init(bridgeURL: URL(string: "https://bridge.example.org/bridge")!, network: "-239", lastEventId: "41")) { data, id in
            XCTAssertEqual(data, message)
            if let id { ids.append(id) }
        }
        XCTAssertEqual(ids, ["42", "43"])
    }
}

private final class TonConnectFixtureURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String, Data))?
    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler, let url = request.url else { throw URLError(.badURL) }
            let (status, type, data) = try handler(request)
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": type, "Content-Length": String(data.count)])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
    static func body(_ request: URLRequest) throws -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { throw URLError(.cannotDecodeRawData) }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var bytes = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            guard count >= 0 else { throw URLError(.cannotDecodeRawData) }
            if count == 0 { break }
            data.append(contentsOf: bytes.prefix(count))
        }
        return data
    }
}


extension LegacyTonConnectServiceTests {
    func testUnsupportedRPCRepliesDurablyAndDoesNotBlockNextValidRequest() async throws {
        let session = try tonConnectTestSession()
        let keys = TonConnectFixtureKeychain()
        let storage = TonConnectFakeSessionStore(values: [session])
        let handler = TonConnectFakeHandler()
        let service = LegacyTonConnectService(store: storage, replies: .init(keystore: keys), transport: TonConnectFakeTransport())
        await service.set(handler: handler)
        let invalid = Data(#"{"id":"old-method","method":"unknownMethod","params":[]}"#.utf8)
        let response = try await service.handle(invalid, session: session, network: "-239")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
        XCTAssertEqual((json["error"] as? [String: Any])?["code"] as? Int, 400)
        let replay = try await service.handle(invalid, session: session, network: "-239")
        XCTAssertEqual(replay, response)
        XCTAssertEqual(handler.processCount, 0)
        _ = try await service.handle(Data(#"{"id":"valid","method":"sendTransaction","params":["{}"]}"#.utf8), session: session, network: "-239")
        XCTAssertEqual(handler.processCount, 1)
        XCTAssertEqual(storage.values, [session])
    }

    func testPermanentMalformedInputIsRepliedButTemporaryWalletFailureCanRetry() async throws {
        let session = try tonConnectTestSession()
        let keys = TonConnectFixtureKeychain()
        let handler = TonConnectFakeHandler()
        let service = LegacyTonConnectService(store: TonConnectFakeSessionStore(values: [session]), replies: .init(keystore: keys), transport: TonConnectFakeTransport())
        await service.set(handler: handler)
        handler.processError = LegacyTonConnectError.expiredRequest
        let expired = Data(#"{"id":"expired","method":"sendTransaction","params":["{}"]}"#.utf8)
        let reply = try await service.handle(expired, session: session, network: "-239")
        handler.processError = nil
        let replay = try await service.handle(expired, session: session, network: "-239")
        XCTAssertEqual(reply, replay)
        XCTAssertEqual(handler.processCount, 1)
        handler.processError = LegacyTonConnectError.unavailableWallet
        let retryable = Data(#"{"id":"locked","method":"sendTransaction","params":["{}"]}"#.utf8)
        do { _ = try await service.handle(retryable, session: session, network: "-239"); XCTFail("Wallet is temporarily locked") } catch {}
        handler.processError = nil
        _ = try await service.handle(retryable, session: session, network: "-239")
        XCTAssertEqual(handler.processCount, 3)
        XCTAssertEqual(handler.acknowledgeCount, 1)
    }
}

private func tonConnectTestWallet(_ keys: TonConnectFixtureKeychain) throws -> MetaAccountModel {
    let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: tonConnectNativePhrase.components(separatedBy: " "))
    let account = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(WalletV4R2(publicKey: pair.publicKey.data).address()),
                                       publicKey: pair.publicKey.data, contractVersion: "v4R2")
    keys.values[KeystoreTagV2.tonSecretKeyTagForMetaId("legacy-wallet")] = pair.privateKey.data
    return MetaAccountModel(metaId: "legacy-wallet", name: "Original native TON", substrateAccountId: nil,
        substrateCryptoType: 0, substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil,
        chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: false, unusedChainIds: nil,
        selectedCurrency: .defaultCurrency(), networkManagmentFilter: nil, assetsVisibility: [],
        hasBackup: true, favouriteChainIds: [], legacyTonAccount: account)
}

final class LegacyTonConnectCoordinatorTests: XCTestCase {
    private func wallet(_ keys: TonConnectFixtureKeychain) throws -> MetaAccountModel {
        try tonConnectTestWallet(keys)
    }

    private var request: LegacyTonConnectConnectRequest {
        .init(manifestUrl: URL(string: "https://example.org/manifest.json")!, items: [.init(name: "ton_addr", payload: nil)])
    }
    private var manifest: LegacyTonConnectManifest {
        .init(url: URL(string: "https://example.org/app")!, name: "Original application", iconUrl: nil)
    }

    @MainActor
    func testReconnectingNativeJSWalletPreservesSessionKeysAndBoundNetwork() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let session = try tonConnectTestSession(clientId: UUID().uuidString, type: "js")
        let storage = TonConnectFakeSessionStore(values: [session])
        let replies = LegacyTonConnectReplyStore(keystore: keys)
        try replies.save(context: .init(bridgeURL: session.appUrl, network: "-3", lastEventId: nil), sessionId: session.identifier)
        let original = keys.values
        var details = ""
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: replies,
            keystore: keys, selectedWallet: { wallet }, networkSelection: { "-239" },
            approval: { _, value in details = value; return true }, walletLoader: { _ in wallet })
        await coordinator.activate()
        let response = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
        let payload = try XCTUnwrap(json["payload"] as? [String: Any])
        let items = try XCTUnwrap(payload["items"] as? [[String: Any]])
        XCTAssertEqual(items.first?["address"] as? String, try wallet.legacyTonAccount.map { try TonSwift.Address.parse($0.address).toRaw() })
        XCTAssertEqual(items.first?["network"] as? String, "-3")
        XCTAssertTrue(details.contains("TON Testnet"))
        XCTAssertTrue(details.contains(wallet.name))
        XCTAssertEqual(storage.values, [session])
        XCTAssertEqual(keys.values, original)
        coordinator.throttle()
    }

    /// MoldyRoost step 1: an address-only connection shares public data and reads no wallet
    /// secret; the key is read once, only to sign an approved ownership proof.
    @MainActor
    func testAddressOnlyConnectReadsNoWalletSecretAndAProofReadsTheKeyOnce() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let secrets = TonConnectSecretReadSpy(keys)
        let storage = TonConnectFakeSessionStore(values: [])
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: secrets, selectedWallet: { wallet }, approval: { _, _ in true }, walletLoader: { _ in wallet },
            isEnabled: { true }, isSigningEnabled: { true })
        await coordinator.activate()

        let addressOnly = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js")
        let addressItems = try XCTUnwrap(((JSONSerialization.jsonObject(with: addressOnly) as? [String: Any])?["payload"] as? [String: Any])?["items"] as? [[String: Any]])
        XCTAssertEqual(addressItems.count, 1)
        XCTAssertEqual(secrets.reads, [], "An address-only connection must not read the spending key")

        let proofRequest = LegacyTonConnectConnectRequest(
            manifestUrl: request.manifestUrl,
            items: request.items + [.init(name: "ton_proof", payload: "moldyroost-proof")]
        )
        let proofResponse = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: proofRequest, manifest: manifest, connectionType: "js")
        let proofItems = try XCTUnwrap(((JSONSerialization.jsonObject(with: proofResponse) as? [String: Any])?["payload"] as? [String: Any])?["items"] as? [[String: Any]])
        XCTAssertNotNil(proofItems.last?["proof"])
        XCTAssertEqual(secrets.reads, [KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)])
        coordinator.throttle()
    }

    /// Codex review (round 2): a TON Connect link opened while the app is locked waits for the unlock.
    @MainActor
    func testALinkOpenedWhileLockedIsKeptUntilTheUnlock() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let transport = TonConnectFakeTransport()
        var approvals = 0
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectFakeSessionStore(values: []), transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return false },
            walletLoader: { _ in wallet }, isEnabled: { true }
        )
        await coordinator.activate()
        let peer = try tonConnectTestSession().clientId
        var parts = URLComponents(string: "tc://")!
        parts.queryItems = [
            .init(name: "v", value: "2"), .init(name: "id", value: peer),
            .init(name: "r", value: #"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#)
        ]
        let url = try XCTUnwrap(parts.url)
        let otherPeer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 5, count: 32)).publicKey
        parts.queryItems?[1] = .init(name: "id", value: otherPeer.map { String(format: "%02x", $0) }.joined())
        let second = try XCTUnwrap(parts.url)
        let lockState = ApplicationLockState.shared
        lockState.markLockPending()
        defer { lockState.cancelPendingLock() }

        coordinator.open(url)
        coordinator.open(second)
        coordinator.open(url)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(transport.manifestCalls, 0, "Nothing is prepared behind the lock")
        XCTAssertEqual(approvals, 0)

        lockState.cancelPendingLock()
        for _ in 0 ..< 150 where approvals < 2 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(approvals, 2, "Both kept links run, once each, after the unlock")
        XCTAssertEqual(transport.manifestCalls, 2)
        coordinator.throttle()
    }

    /// Codex review (round 4): a link that meets another open approval waits for it, and a duplicate arriving while
    /// it is handled is merged with it.
    @MainActor
    func testALinkWaitsForAnotherApprovalAndDuplicatesAreMerged() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let transport = TonConnectFakeTransport()
        var approvals = 0
        var gate: CheckedContinuation<Void, Never>?
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectFakeSessionStore(values: []), transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet },
            approval: { _, _ in
                approvals += 1
                if approvals == 1 {
                    await withCheckedContinuation { gate = $0 }
                }
                return false
            },
            walletLoader: { _ in wallet }, isEnabled: { true }
        )
        await coordinator.activate()
        let request = try JSONDecoder().decode(
            LegacyTonConnectConnectRequest.self,
            from: Data(#"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#.utf8)
        )
        let competing = Task { @MainActor in
            _ = try? await coordinator.connect(
                walletId: wallet.metaId, clientId: try tonConnectTestSession().clientId, request: request,
                manifest: .init(url: URL(string: "https://example.org")!, name: "Other", iconUrl: nil), connectionType: "http"
            )
        }
        for _ in 0 ..< 100 where gate == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNotNil(gate, "Another approval is open")

        let peer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 5, count: 32)).publicKey
        var parts = URLComponents(string: "tc://")!
        parts.queryItems = [
            .init(name: "v", value: "2"), .init(name: "id", value: peer.map { String(format: "%02x", $0) }.joined()),
            .init(name: "r", value: #"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#)
        ]
        let url = try XCTUnwrap(parts.url)
        coordinator.open(url)
        for _ in 0 ..< 100 where transport.manifestCalls == 0 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        coordinator.open(url)
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(approvals, 1, "The link waits while the other approval is open")
        XCTAssertEqual(transport.manifestCalls, 1)

        gate?.resume()
        await competing.value
        for _ in 0 ..< 150 where approvals < 2 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(approvals, 2, "The kept link is asked once, after the other approval ended")
        XCTAssertEqual(transport.manifestCalls, 2)
        coordinator.throttle()
    }

    /// Codex review (rounds 5 and 6): a wallet throttled while a request was being prepared asks nothing.
    @MainActor
    func testAThrottledWalletIsNeverAskedToApprove() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        var approvals = 0
        var lookup: CheckedContinuation<Void, Never>?
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectFakeSessionStore(values: []), transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            // Declines, so a regression fails the assertions instead of waiting for a second lookup.
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return false },
            walletLoader: { _ in
                if lookup == nil {
                    await withCheckedContinuation { lookup = $0 }
                }
                return wallet
            },
            isEnabled: { true }
        )
        await coordinator.activate()
        let request = try JSONDecoder().decode(
            LegacyTonConnectConnectRequest.self,
            from: Data(#"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#.utf8)
        )
        let connecting = Task { @MainActor () -> Error? in
            do {
                _ = try await coordinator.connect(
                    walletId: wallet.metaId, clientId: try tonConnectTestSession().clientId, request: request,
                    manifest: .init(url: URL(string: "https://example.org")!, name: "Fixture", iconUrl: nil), connectionType: "http"
                )
                return nil
            } catch {
                return error
            }
        }
        for _ in 0 ..< 100 where lookup == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNotNil(lookup, "connect passed its entry check and is loading the wallet")
        coordinator.throttle()
        try await Task.sleep(nanoseconds: 50_000_000)
        lookup?.resume()
        let error = await connecting.value

        guard case LegacyTonConnectError.busy? = error as? LegacyTonConnectError else {
            return XCTFail("Expected busy, got \(String(describing: error))")
        }
        XCTAssertEqual(approvals, 0)
    }

    /// Codex review (round 5): a link that fails after the user decided is not asked about again.
    @MainActor
    func testALinkThatFailsAfterTheDecisionIsNotAskedAgain() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let transport = TonConnectFakeTransport()
        transport.failSends = true
        var approvals = 0
        let lockState = ApplicationLockState.shared
        defer { lockState.cancelPendingLock() }
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectFakeSessionStore(values: []), transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet },
            approval: { _, _ in
                approvals += 1
                // The app locks right after the decision; the declined reply then fails to leave.
                lockState.markLockPending()
                return false
            },
            walletLoader: { _ in wallet }, isEnabled: { true }
        )
        await coordinator.activate()
        let peer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 5, count: 32)).publicKey
        var parts = URLComponents(string: "tc://")!
        parts.queryItems = [
            .init(name: "v", value: "2"), .init(name: "id", value: peer.map { String(format: "%02x", $0) }.joined()),
            .init(name: "r", value: #"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#)
        ]
        coordinator.open(try XCTUnwrap(parts.url))
        for _ in 0 ..< 100 where approvals == 0 {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await Task.sleep(nanoseconds: 200_000_000)
        lockState.cancelPendingLock()
        try await Task.sleep(nanoseconds: 400_000_000)

        XCTAssertEqual(approvals, 1, "Decided once, never asked again")
        XCTAssertEqual(transport.manifestCalls, 1)
        coordinator.throttle()
    }

    @MainActor
    func testDeclinedHTTPConnectionRepliesWithoutPersistingSessionOrChangingSecrets() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let original = keys.values
        let storage = TonConnectFakeSessionStore(values: [])
        let transport = TonConnectFakeTransport()
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in false }, walletLoader: { _ in wallet })
        await coordinator.activate()
        let result = try await coordinator.connect(walletId: wallet.metaId, clientId: tonConnectTestSession().clientId,
            request: request, manifest: manifest, connectionType: "http")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: result) as? [String: Any])
        XCTAssertEqual(json["event"] as? String, "connect_error")
        XCTAssertEqual(transport.sent.count, 1)
        XCTAssertEqual(transport.sent.first?.0, result)
        XCTAssertTrue(storage.values.isEmpty)
        XCTAssertEqual(keys.values, original)
        coordinator.throttle()
    }

    @MainActor
    func testCDNManifestConnectionDisplaysBothOriginsAndKeepsOriginalNativeKey() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let originalSecret = keys.values[KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)]
        let storage = TonConnectFakeSessionStore(values: [])
        var details = ""
        let transport = TonConnectFakeTransport()
        transport.manifestValue = manifest
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, value in details = value; return true }, walletLoader: { _ in wallet })
        await coordinator.activate()
        let cdnRequest = LegacyTonConnectConnectRequest(manifestUrl: URL(string: "https://cdn.example.org/tonconnect.json")!, items: request.items)
        do { _ = try await coordinator.connectJS(request: cdnRequest, origin: URL(string: "https://other.example.org")!); XCTFail("CDN must not bypass displayed application origin") } catch {}
        XCTAssertTrue(storage.values.isEmpty)
        XCTAssertTrue(details.isEmpty)
        _ = try await coordinator.connectJS(request: cdnRequest, origin: manifest.url)
        XCTAssertTrue(details.contains("Application: https://example.org/app"))
        XCTAssertTrue(details.contains("Manifest: https://cdn.example.org/tonconnect.json"))
        XCTAssertEqual(storage.values.first?.appUrl, manifest.url)
        XCTAssertEqual(keys.values[KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)], originalSecret)
        coordinator.throttle()
    }

    @MainActor
    func testNewJSConnectionRequiresApprovalAndPreservesOtherSessionsAndNativeSecret() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let originalSecret = keys.values[KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)]
        let unrelated = try tonConnectTestSession(id: "unrelated", type: "js")
        let storage = TonConnectFakeSessionStore(values: [unrelated])
        var approvals = 0
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet })
        await coordinator.activate()
        let otherManifest = LegacyTonConnectManifest(url: URL(string: "https://new.example.org")!, name: "New application", iconUrl: nil)
        let otherRequest = LegacyTonConnectConnectRequest(manifestUrl: URL(string: "https://new.example.org/manifest.json")!, items: request.items)
        _ = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: otherRequest, manifest: otherManifest, connectionType: "js")
        XCTAssertEqual(approvals, 1)
        XCTAssertEqual(storage.values.count, 2)
        XCTAssertTrue(storage.values.contains(unrelated))
        let created = try XCTUnwrap(storage.values.first { $0.identifier != unrelated.identifier })
        XCTAssertNoThrow(try created.validated())
        XCTAssertNotNil(UUID(uuidString: created.clientId))
        XCTAssertEqual(created.walletId, wallet.metaId)
        XCTAssertEqual(keys.values[KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)], originalSecret)
        coordinator.throttle()
    }

    @MainActor
    func testJSRestoreUsesPersistedNativeIdentityWithoutSecretReadOrApproval() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        keys.values.removeAll() // Restore is a public account reply, even while keys are locked.
        let session = try tonConnectTestSession(clientId: UUID().uuidString, type: "js")
        let storage = TonConnectFakeSessionStore(values: [session])
        var approvals = 0
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet })
        await coordinator.activate()
        let data = try await coordinator.restoreJS(origin: manifest.url)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(json["event"] as? String, "connect")
        XCTAssertEqual(approvals, 0)
        XCTAssertNil(keys.values[KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)])
        XCTAssertEqual(storage.values, [session])
        coordinator.throttle()
    }

    @MainActor
    func testReleasedSessionCosmeticsDoNotBlockPublicRestoreOrChangeStoredIdentity() async throws {
        for name in ["", String(repeating: "Legacy application ", count: 32)] {
            let keys = TonConnectFixtureKeychain()
            let wallet = try wallet(keys)
            keys.values.removeAll()
            let original = try tonConnectTestSession(clientId: UUID().uuidString, type: "js")
            let session = LegacyTonConnectSession(identifier: original.identifier, walletId: original.walletId,
                clientId: original.clientId, appUrl: original.appUrl, name: name,
                iconUrl: URL(string: "http://legacy.example.org/icon.png")!, publicKey: original.publicKey,
                privateKey: original.privateKey, connectionType: original.connectionType)
            XCTAssertNoThrow(try session.validated())
            let storage = TonConnectFakeSessionStore(values: [session])
            let replies = LegacyTonConnectReplyStore(keystore: keys)
            try replies.save(context: .init(bridgeURL: session.appUrl, network: "-3", lastEventId: nil), sessionId: session.identifier)
            let storedKeys = keys.values
            var approvals = 0
            let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: replies,
                keystore: keys, selectedWallet: { wallet }, networkSelection: { "-239" },
                approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet })
            await coordinator.activate()
            let data = try await coordinator.restoreJS(origin: session.appUrl)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            let payload = try XCTUnwrap(json["payload"] as? [String: Any])
            let items = try XCTUnwrap(payload["items"] as? [[String: Any]])
            XCTAssertEqual(items.first?["network"] as? String, "-3")
            XCTAssertEqual(items.first?["address"] as? String, try wallet.legacyTonAccount.map { try TonSwift.Address.parse($0.address).toRaw() })
            XCTAssertEqual(approvals, 0)
            XCTAssertEqual(storage.values, [session])
            XCTAssertEqual(keys.values, storedKeys)
            do { _ = try await coordinator.restoreJS(origin: URL(string: "https://other.example.org")!); XCTFail("Wrong origin") } catch {}
            coordinator.throttle()
        }
    }

    @MainActor
    func testOriginAndWalletSwitchCannotRestoreAnotherApplicationsSession() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        var selected: MetaAccountModel? = wallet
        let session = try tonConnectTestSession(clientId: UUID().uuidString, type: "js")
        let storage = TonConnectFakeSessionStore(values: [session])
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { selected }, approval: { _, _ in XCTFail("No approval for another origin"); return true }, walletLoader: { _ in wallet })
        await coordinator.activate()
        do { _ = try await coordinator.restoreJS(origin: URL(string: "https://other.example.org")!); XCTFail("Wrong origin") } catch {}
        do { _ = try await coordinator.connectJS(request: request, origin: URL(string: "https://other.example.org")!); XCTFail("Wrong manifest origin") } catch {}
        selected = nil
        do { _ = try await coordinator.restoreJS(origin: manifest.url); XCTFail("No selected wallet") } catch {}
        XCTAssertEqual(storage.values, [session])
        coordinator.throttle()
    }

    @MainActor
    func testWalletChangedDuringApprovalCannotSignOrPersistNewSession() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let original = keys.values
        let storage = TonConnectFakeSessionStore(values: [])
        var changed = false
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in changed = true; return true },
            walletLoader: { _ in
                if changed { throw LegacyTonConnectError.unavailableWallet }
                return wallet
            })
        await coordinator.activate()
        do { _ = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js"); XCTFail("Deleted wallet") } catch {}
        XCTAssertTrue(storage.values.isEmpty)
        XCTAssertEqual(keys.values, original)
        coordinator.throttle()
    }

    /// An address-only connection never reads the key, so a damaged key cannot stop it and is
    /// left as it is; a proof sign-in reads it, refuses it and saves nothing.
    @MainActor
    func testDamagedExistingNativeSecretDoesNotReplaceItOnReconnect() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let tag = KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)
        keys.values[tag] = Data(repeating: 0, count: 64)
        let storage = TonConnectFakeSessionStore(values: [])
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in true }, walletLoader: { _ in wallet },
            isEnabled: { true }, isSigningEnabled: { true })
        await coordinator.activate()
        let proofRequest = LegacyTonConnectConnectRequest(
            manifestUrl: request.manifestUrl,
            items: request.items + [.init(name: "ton_proof", payload: "damaged-key-proof")]
        )
        do { _ = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: proofRequest, manifest: manifest, connectionType: "js"); XCTFail("Damaged original key") } catch {}
        XCTAssertEqual(keys.values[tag], Data(repeating: 0, count: 64))
        XCTAssertTrue(storage.values.isEmpty)

        _ = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js")
        XCTAssertEqual(keys.values[tag], Data(repeating: 0, count: 64), "The damaged key is never replaced")
        XCTAssertEqual(storage.values.count, 1)
        coordinator.throttle()
    }

    @MainActor
    func testSelectedSessionInventoryAndExplicitDisconnectKeepOtherSessions() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let first = try tonConnectTestSession(id: "first", type: "js")
        let second = try tonConnectTestSession(id: "second", type: "js")
        let storage = TonConnectFakeSessionStore(values: [first, second])
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, walletLoader: { _ in wallet })
        await coordinator.activate()
        let before = try await coordinator.selectedSessions()
        XCTAssertEqual(before, [first, second])
        try await coordinator.disconnect(first)
        let after = try await coordinator.selectedSessions()
        XCTAssertEqual(after, [second])
        coordinator.throttle()
    }

    func testURLHandlerOnlyConsumesTonConnectSchemeAndDispatchesToMain() async throws {
        let invoked = expectation(description: "Original deep link routed")
        let url = URL(string: "tc://?v=2")!
        let handler = LegacyTonConnectURLHandler { value in
            XCTAssertTrue(Thread.isMainThread)
            XCTAssertEqual(value, url)
            invoked.fulfill()
        }
        XCTAssertFalse(handler.handle(url: URL(string: "iroha://connect")!))
        XCTAssertTrue(handler.handle(url: url))
        await fulfillment(of: [invoked], timeout: 2)
    }

    func testJSInvocationRejectsOversizedIdsMessagesAndUnknownMethods() throws {
        let valid = Data(#"{"id":"1","method":"restoreConnection"}"#.utf8)
        XCTAssertEqual(try LegacyTonConnectJSInvocation.decode(valid).method, "restoreConnection")
        for object in [["id": "", "method": "send"], ["id": String(repeating: "x", count: 129), "method": "send"], ["id": "1", "method": "signAnything"]] {
            XCTAssertThrowsError(try LegacyTonConnectJSInvocation.decode(JSONSerialization.data(withJSONObject: object)))
        }
        XCTAssertThrowsError(try LegacyTonConnectJSInvocation.decode(Data(repeating: 32, count: 65537)))
    }
}


extension LegacyTonConnectProtocolTests {
    func testReleasedUniversalTonConnectPathKeepsTheSameRequestAndPeer() throws {
        let peer = try tonConnectTestSession().clientId
        let request = #"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#
        for base in ["https://fearlesswallet.io/ton-connect", "fearless:///ton-connect"] {
            var parts = URLComponents(string: base)!
            parts.queryItems = [.init(name: "v", value: "2"), .init(name: "id", value: peer), .init(name: "r", value: request)]
            let parsed = try LegacyTonConnectProtocol.parseLink(XCTUnwrap(parts.url))
            XCTAssertEqual(parsed.clientId, peer)
            XCTAssertEqual(parsed.request.items.first?.name, "ton_addr")
        }
        XCTAssertNil(LegacyTonConnectProtocol.canonicalLink(URL(string: "https://example.org/other")!))
        XCTAssertNil(LegacyTonConnectProtocol.canonicalLink(URL(string: "file:///ton-connect")!))
    }
}

final class LegacyTonConnectViewTests: XCTestCase {
    @MainActor
    func testApprovalSupportsSmallScreensAndDeclinesOnlyOnce() throws {
        let controller = LegacyTonConnectApprovalViewController(title: "Review TON transaction", details: String(repeating: "Original wallet address and reviewed contract effects.\n", count: 120))
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        controller.view.layoutIfNeeded()
        let scroll = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIScrollView }.first)
        XCTAssertGreaterThan(scroll.contentSize.height, scroll.bounds.height)
        let stack = try XCTUnwrap(scroll.subviews.compactMap { $0 as? UIStackView }.first)
        let buttons = stack.arrangedSubviews.compactMap { $0 as? UIButton }
        XCTAssertEqual(buttons.count, 2)
        XCTAssertTrue(buttons.allSatisfy { $0.bounds.height >= 48 && $0.bounds.width <= 280 })
        var completions: [Bool?] = []
        controller.completion = { completions.append($0) }
        controller.finish(approved: false)
        controller.finish(approved: true)
        XCTAssertEqual(completions, [false])
    }

    @MainActor
    func testRealWebKitBridgePublishesReleasedProviderAndHandlesStructuredReplies() async throws {
        let coordinator = LegacyTonConnectCoordinator(store: TonConnectFakeSessionStore(values: []), transport: TonConnectFakeTransport(),
                                                       replies: .init(keystore: TonConnectFixtureKeychain()), selectedWallet: { nil })
        // A non-origin start URL avoids starting and cancelling an unrelated
        // network navigation before the synthetic page; the shipped WebView
        // configuration and document-start provider injection are unchanged.
        let controller = LegacyTonConnectBrowserViewController(url: URL(string: "about:blank")!, coordinator: coordinator)
        controller.loadViewIfNeeded()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive }))
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let appeared = expectation(description: "TON browser is displayed in the foreground scene")
        let navigation = TonConnectTestBrowserNavigationController(rootViewController: controller)
        navigation.didAppear = { appeared.fulfill() }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = navigation
        defer {
            controller.webView.stopLoading()
            controller.webView.navigationDelegate = nil
            navigation.didAppear = nil
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        }
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        await fulfillment(of: [appeared], timeout: 10)
        guard navigation.hasAppeared else { return }
        guard window.isKeyWindow, !window.isHidden, scene.activationState == .foregroundActive,
              controller.view.window === window, controller.webView.window === window,
              controller.webView.bounds.width > 0, controller.webView.bounds.height > 0 else {
            XCTFail("TON browser must have a nonempty WebView displayed in the active scene")
            return
        }

        let loaded = expectation(description: "The intended synthetic WKWebView navigation completes")
        let delegate = TonConnectTestNavigationDelegate { loaded.fulfill() }
        controller.webView.navigationDelegate = delegate
        delegate.expectedNavigation = try XCTUnwrap(controller.webView.loadHTMLString(
            "<!doctype html><html><body id='ton-connect-test-fixture'>Public TonConnect fixture</body></html>",
            baseURL: URL(string: "https://example.org")!
        ))
        // WebContent is a separate process: allow bounded startup time in the
        // full suite, then require the actual navigation outcome, not a sleep.
        await fulfillment(of: [loaded], timeout: 30)
        try XCTUnwrap(delegate.outcome, "The intended synthetic navigation did not report an outcome").get()
        let documentState = try await controller.webView.evaluateJavaScript(
            "[document.body?.id, document.readyState, document.visibilityState].join('|')"
        )
        XCTAssertEqual(documentState as? String, "ton-connect-test-fixture|complete|visible")
        guard documentState as? String == "ton-connect-test-fixture|complete|visible" else { return }
        let info = try await controller.webView.evaluateJavaScript("JSON.stringify({ version: window.Fearless.tonconnect.protocolVersion, max: window.Fearless.tonconnect.deviceInfo.features[0].maxMessages, appName: window.Fearless.tonconnect.deviceInfo.appName, browser: window.Fearless.tonconnect.isWalletBrowser })")
        let json = try XCTUnwrap((info as? String).flatMap { $0.data(using: .utf8) })
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        XCTAssertEqual(object["version"] as? Int, 2)
        XCTAssertEqual(object["max"] as? Int, 4)
        XCTAssertEqual(object["appName"] as? String, "Fearless")
        XCTAssertEqual(object["browser"] as? Bool, true)
        // Exercise the actual injected JS Promise/listener surface without a
        // transaction or external application. Native calls are captured here.
        let answer = try await controller.webView.callAsyncJavaScript("""
        let captured;
        window.webkit.messageHandlers.legacyTonConnect.postMessage = value => { captured = JSON.parse(value); };
        const result = window.Fearless.tonconnect.send({ id: 'rpc1', method: 'sendTransaction', params: ['{}'] });
        window.Fearless.tonconnect._complete(captured.id, true, JSON.stringify({ id: 'rpc1', result: 'fixture-boc' }));
        return JSON.stringify(await result);
        """, arguments: [:], in: nil, contentWorld: .page)
        let reply = try XCTUnwrap(answer as? String)
        XCTAssertTrue(reply.contains("fixture-boc"))
        _ = delegate // Retain the weak WK navigation delegate until loading completes.
    }
}

private final class TonConnectTestBrowserNavigationController: UINavigationController {
    var didAppear: (() -> Void)?
    private(set) var hasAppeared = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAppeared else { return }
        hasAppeared = true
        didAppear?()
    }
}

private final class TonConnectTestNavigationDelegate: NSObject, WKNavigationDelegate {
    var expectedNavigation: WKNavigation?
    private(set) var outcome: Result<Void, Error>?
    private let loaded: () -> Void
    init(loaded: @escaping () -> Void) { self.loaded = loaded }

    private func finish(_ result: Result<Void, Error>, navigation: WKNavigation?) {
        guard let expectedNavigation, navigation === expectedNavigation, outcome == nil else { return }
        outcome = result
        loaded()
    }

    func webView(_: WKWebView, didFinish navigation: WKNavigation!) {
        finish(.success(()), navigation: navigation)
    }

    func webView(_: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error), navigation: navigation)
    }

    func webView(_: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finish(.failure(error), navigation: navigation)
    }

    func webViewWebContentProcessDidTerminate(_: WKWebView) {
        let error = NSError(domain: "TonConnectTestWebContent", code: 1,
                            userInfo: [NSLocalizedDescriptionKey: "WebContent process terminated while loading the synthetic fixture"])
        finish(.failure(error), navigation: expectedNavigation)
    }
}


extension LegacyTonConnectReplyTests {
    func testUnchangedSessionContextDoesNotRewriteOrRequireWritableKeychain() throws {
        let keys = TonConnectFixtureKeychain()
        let replies = LegacyTonConnectReplyStore(keystore: keys)
        let context = LegacyTonConnectSessionContext(bridgeURL: URL(string: "https://example.org/app")!, network: "-239", lastEventId: "40")
        try replies.save(context: context, sessionId: "original")
        let original = keys.values
        keys.failWrites = true
        XCTAssertNoThrow(try replies.save(context: context, sessionId: "original"))
        XCTAssertEqual(keys.values, original)
        var changed = context
        changed.lastEventId = "41"
        XCTAssertThrowsError(try replies.save(context: changed, sessionId: "original"))
        XCTAssertEqual(try replies.context(sessionId: "original"), context)
    }
}

extension LegacyTonConnectProtocolTests {
    func testManifestClaimIsVouchedOnlyBySameSiteOrSubdomain() throws {
        let cases: [(claimed: String, voucher: String, vouched: Bool)] = [
            ("https://example.org/app", "https://example.org/manifest.json", true),
            ("https://EXAMPLE.org/app", "https://example.ORG/manifest.json", true),
            ("https://app.example.org", "https://example.org/manifest.json", true),
            ("https://example.org", "https://cdn.example.org/manifest.json", true),
            ("https://a.example.org", "https://b.example.org/manifest.json", false),
            ("https://example.org", "https://notexample.org/manifest.json", false),
            ("https://example.org", "https://example.org.attacker.example/manifest.json", false),
            ("https://wallet-login.example.org", "https://raw.githubusercontent.com/manifest.json", false),
            ("https://1.2.3.4", "https://2.3.4/manifest.json", false),
            ("https://10.0.0.1", "https://10.0.0.1/manifest.json", true)
        ]
        for item in cases {
            let claimed = try XCTUnwrap(URL(string: item.claimed))
            let voucher = try XCTUnwrap(URL(string: item.voucher))
            XCTAssertEqual(
                LegacyTonConnectProtocol.isVouched(claimed: claimed, by: voucher), item.vouched,
                item.claimed + " vouched by " + item.voucher
            )
        }
    }

    func testProofIsSignedOnlyForASiteItsVoucherBacks() throws {
        let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: tonConnectNativePhrase.components(separatedBy: " "))
        let address = try WalletV4R2(publicKey: pair.publicKey.data).address()
        let account = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(address), publicKey: pair.publicKey.data, contractVersion: "v4R2")
        let claimed = LegacyTonConnectManifest(url: URL(string: "https://wallet-login.example.org/app")!, name: "Trusted exchange", iconUrl: nil)
        let spoofed = LegacyTonConnectConnectRequest(
            manifestUrl: URL(string: "https://attacker.example.net/tonconnect-manifest.json")!,
            items: [.init(name: "ton_addr", payload: nil), .init(name: "ton_proof", payload: "login-challenge")]
        )
        XCTAssertThrowsError(try LegacyTonConnectProtocol.connectEvent(
            account: account, privateKey: pair.privateKey.data, network: "-239", request: spoofed, manifest: claimed, timestamp: 1
        )) { error in
            guard case let LegacyTonConnectError.unverifiedApplication(claimedHost, sourceHost) = error else {
                return XCTFail("Unexpected \(error)")
            }
            XCTAssertEqual(claimedHost, "wallet-login.example.org")
            XCTAssertEqual(sourceHost, "attacker.example.net")
        }
        // The verified page that asked in the in-app browser vouches for its own site.
        let response = try LegacyTonConnectProtocol.connectEvent(
            account: account, privateKey: pair.privateKey.data, network: "-239", request: spoofed, manifest: claimed,
            timestamp: 1, vouchedBy: URL(string: "https://wallet-login.example.org/")!
        )
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
        let items = try XCTUnwrap((json["payload"] as? [String: Any])?["items"] as? [[String: Any]])
        let proof = try XCTUnwrap(items.last?["proof"] as? [String: Any])
        XCTAssertEqual((proof["domain"] as? [String: Any])?["value"] as? String, "wallet-login.example.org")
        // An address-only connection carries no proof, so no domain is ever signed.
        let addressOnly = LegacyTonConnectConnectRequest(manifestUrl: spoofed.manifestUrl, items: [.init(name: "ton_addr", payload: nil)])
        XCTAssertNoThrow(try LegacyTonConnectProtocol.connectEvent(
            account: account, privateKey: nil, network: "-239", request: addressOnly, manifest: claimed, timestamp: 1
        ))
    }
}

extension LegacyTonConnectServiceTests {
    func testVetoedSigningRequestGetsOneDurableUnsupportedReply() async throws {
        let session = try tonConnectTestSession()
        let handler = TonConnectFakeHandler()
        handler.processError = LegacyTonConnectError.disabled
        let service = LegacyTonConnectService(store: TonConnectFakeSessionStore(values: [session]),
                                              replies: .init(keystore: TonConnectFixtureKeychain()), transport: TonConnectFakeTransport())
        await service.set(handler: handler)
        let request = Data(#"{"id":"vetoed","method":"sendTransaction","params":["{}"]}"#.utf8)
        let reply = try await service.handle(request, session: session, network: "-239")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: reply) as? [String: Any])
        XCTAssertEqual((json["error"] as? [String: Any])?["code"] as? Int, 400)
        handler.processError = nil
        let replay = try await service.handle(request, session: session, network: "-239")
        XCTAssertEqual(replay, reply, "A vetoed request is answered once and never signed later")
        XCTAssertEqual(handler.processCount, 1)
        XCTAssertEqual(handler.acknowledgeCount, 0)
    }

    func testPausedSigningRequestGetsOneDurableUnsupportedReply() async throws {
        let session = try tonConnectTestSession()
        let handler = TonConnectFakeHandler()
        handler.processError = LegacyTonConnectError.signingPaused
        let service = LegacyTonConnectService(store: TonConnectFakeSessionStore(values: [session]),
                                              replies: .init(keystore: TonConnectFixtureKeychain()), transport: TonConnectFakeTransport())
        await service.set(handler: handler)
        let request = Data(#"{"id":"paused","method":"sendTransaction","params":["{}"]}"#.utf8)
        let reply = try await service.handle(request, session: session, network: "-239")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: reply) as? [String: Any])
        XCTAssertEqual((json["error"] as? [String: Any])?["code"] as? Int, 400)
        handler.processError = nil
        let replay = try await service.handle(request, session: session, network: "-239")
        XCTAssertEqual(replay, reply, "A paused request is answered once and never signed later")
        XCTAssertEqual(handler.processCount, 1)
    }
}

extension LegacyTonConnectCoordinatorTests {
    private var claimedManifest: LegacyTonConnectManifest {
        .init(url: URL(string: "https://wallet-login.example.org/app")!, name: "Trusted exchange",
              iconUrl: URL(string: "https://wallet-login.example.org/icon.png"))
    }

    private func spoofedRequest(proof: Bool) -> LegacyTonConnectConnectRequest {
        .init(manifestUrl: URL(string: "https://attacker.example.net/tonconnect-manifest.json")!,
              items: [.init(name: "ton_addr", payload: nil)] + (proof ? [.init(name: "ton_proof", payload: "login-challenge")] : []))
    }

    @MainActor
    func testLinkClaimingAnotherSiteNeverGetsASignInProof() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let original = keys.values
        let storage = TonConnectFakeSessionStore(values: [])
        let transport = TonConnectFakeTransport()
        var approvals = 0
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet },
            isEnabled: { true })
        await coordinator.activate()
        do {
            _ = try await coordinator.connect(walletId: wallet.metaId, clientId: tonConnectTestSession().clientId,
                request: spoofedRequest(proof: true), manifest: claimedManifest, connectionType: "http")
            XCTFail("A proof for a site the manifest host does not vouch for must be refused")
        } catch let LegacyTonConnectError.unverifiedApplication(claimedHost, sourceHost) {
            XCTAssertEqual(claimedHost, "wallet-login.example.org")
            XCTAssertEqual(sourceHost, "attacker.example.net")
            XCTAssertFalse(LegacyTonConnectError.unverifiedApplication(claimedHost: claimedHost, sourceHost: sourceHost)
                .localizedDescription.isEmpty)
        }
        XCTAssertEqual(approvals, 0, "Refused before any prompt")
        XCTAssertTrue(storage.values.isEmpty)
        XCTAssertEqual(keys.values, original)
        let reply = try XCTUnwrap(transport.sent.first?.0)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: reply) as? [String: Any])
        XCTAssertEqual(json["event"] as? String, "connect_error")
        XCTAssertEqual((json["payload"] as? [String: Any])?["code"] as? Int, 3)
        coordinator.throttle()
    }

    @MainActor
    func testLinkClaimingAnotherSiteIsShownAndStoredUnderTheServingHost() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let storage = TonConnectFakeSessionStore(values: [])
        let transport = TonConnectFakeTransport()
        var details = ""
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, value in details = value; return true }, walletLoader: { _ in wallet },
            isEnabled: { true })
        await coordinator.activate()
        let response = try await coordinator.connect(walletId: wallet.metaId, clientId: tonConnectTestSession().clientId,
            request: spoofedRequest(proof: false), manifest: claimedManifest, connectionType: "http")
        let lines = details.components(separatedBy: "\n")
        XCTAssertEqual(lines.first, "Application: https://attacker.example.net")
        XCTAssertEqual(lines.dropFirst().first, R.string.localizable.tonconnectDomainMismatch(
            "https://wallet-login.example.org/app", preferredLanguages: LegacyTonConnectProtocol.languages
        ))
        XCTAssertFalse(details.contains("Manifest:"))
        XCTAssertFalse(details.contains("proof of wallet ownership"))
        let session = try XCTUnwrap(storage.values.first)
        XCTAssertEqual(session.appUrl, URL(string: "https://attacker.example.net"))
        XCTAssertEqual(session.name, "attacker.example.net")
        XCTAssertNil(session.iconUrl)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
        let items = try XCTUnwrap((json["payload"] as? [String: Any])?["items"] as? [[String: Any]])
        XCTAssertEqual(items.map { $0["name"] as? String }, ["ton_addr"])
        coordinator.throttle()
    }

    @MainActor
    func testLinkFromASubdomainOfTheClaimedSiteBehavesAsBefore() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let storage = TonConnectFakeSessionStore(values: [])
        var details = ""
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, value in details = value; return true }, walletLoader: { _ in wallet },
            isEnabled: { true })
        await coordinator.activate()
        let cdnRequest = LegacyTonConnectConnectRequest(
            manifestUrl: URL(string: "https://cdn.example.org/tonconnect.json")!,
            items: [.init(name: "ton_addr", payload: nil), .init(name: "ton_proof", payload: "login-challenge")]
        )
        let response = try await coordinator.connect(walletId: wallet.metaId, clientId: tonConnectTestSession().clientId,
            request: cdnRequest, manifest: manifest, connectionType: "http")
        XCTAssertTrue(details.hasPrefix("Application: https://example.org/app\nManifest: https://cdn.example.org/tonconnect.json\n"))
        XCTAssertTrue(details.hasSuffix("\nThe application also requests proof of wallet ownership."))
        XCTAssertEqual(storage.values.first?.appUrl, manifest.url)
        XCTAssertEqual(storage.values.first?.name, manifest.name)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: response) as? [String: Any])
        let items = try XCTUnwrap((json["payload"] as? [String: Any])?["items"] as? [[String: Any]])
        let proof = try XCTUnwrap(items.last?["proof"] as? [String: Any])
        XCTAssertEqual((proof["domain"] as? [String: Any])?["value"] as? String, "example.org")
        coordinator.throttle()
    }

    @MainActor
    func testRemoteVetoRefusesConnectionsAndSigningButKeepsSessionsAndKeys() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let session = try tonConnectTestSession()
        let storage = TonConnectFakeSessionStore(values: [session])
        var approvals = 0
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return true },
            walletLoader: { _ in wallet }, isEnabled: { false })
        await coordinator.activate()
        // Existing sessions keep listening so they can be told TON Connect is paused; that bridge
        // bookkeeping (bridge URL, network, last event id) is the only thing allowed to be written.
        let walletState: ([String: Data]) -> [String: Data] = { values in
            values.filter { !$0.key.hasPrefix("fearless-tonconnect-v1-context-") }
        }
        let original = walletState(keys.values)
        do {
            _ = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js")
            XCTFail("Vetoed connection")
        } catch LegacyTonConnectError.disabled {}
        do {
            _ = try await coordinator.connectJS(request: request, origin: manifest.url)
            XCTFail("Vetoed browser connection")
        } catch LegacyTonConnectError.disabled {}
        let rpc = try LegacyTonConnectRPCRequest.decode(Data(#"{"id":"1","method":"sendTransaction","params":["{}"]}"#.utf8))
        do {
            _ = try await coordinator.process(session: session, network: "-239", request: rpc)
            XCTFail("Vetoed signing")
        } catch LegacyTonConnectError.disabled {}
        XCTAssertEqual(approvals, 0)
        XCTAssertEqual(storage.values, [session])
        XCTAssertEqual(walletState(keys.values), original)
        XCTAssertFalse(LegacyTonConnectError.disabled.localizedDescription.isEmpty)
        coordinator.throttle()
    }

    @MainActor
    func testSigningVetoRefusesTransactionsAndSignInProofsButNotPlainConnections() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let session = try tonConnectTestSession()
        var approvals = 0
        let paused = LegacyTonConnectCoordinator(store: TonConnectFakeSessionStore(values: [session]),
            transport: TonConnectFakeTransport(), replies: .init(keystore: keys), keystore: keys, selectedWallet: { wallet },
            approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet },
            isEnabled: { true }, isSigningEnabled: { false })
        await paused.activate()
        let proofRequest = LegacyTonConnectConnectRequest(
            manifestUrl: request.manifestUrl,
            items: request.items + [.init(name: "ton_proof", payload: "login-challenge")]
        )
        do {
            _ = try await paused.connect(walletId: wallet.metaId, clientId: tonConnectTestSession().clientId,
                request: proofRequest, manifest: manifest, connectionType: "http")
            XCTFail("A sign-in proof is a signature")
        } catch LegacyTonConnectError.signingPaused {}
        let rpc = try LegacyTonConnectRPCRequest.decode(Data(#"{"id":"1","method":"sendTransaction","params":["{}"]}"#.utf8))
        do {
            _ = try await paused.process(session: session, network: "-239", request: rpc)
            XCTFail("Vetoed signing")
        } catch LegacyTonConnectError.signingPaused {}
        XCTAssertEqual(approvals, 0, "Nothing is shown for a paused signature")
        paused.throttle()

        // A connection without a proof signs nothing, so the signing veto leaves it alone.
        let storage = TonConnectFakeSessionStore(values: [])
        let plain = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(),
            replies: .init(keystore: keys), keystore: keys, selectedWallet: { wallet },
            approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet },
            isEnabled: { true }, isSigningEnabled: { false })
        await plain.activate()
        _ = try await plain.connect(walletId: wallet.metaId, clientId: tonConnectTestSession().clientId,
            request: request, manifest: manifest, connectionType: "http")
        XCTAssertEqual(approvals, 1)
        XCTAssertEqual(storage.values.count, 1)
        XCTAssertFalse(LegacyTonConnectError.signingPaused.localizedDescription.isEmpty)
        plain.throttle()
    }
}

/// TON Connect transport keys leave the SQLite store for device-only Keychain items (2026-11-23 audit, finding 5).
final class LegacyTonConnectSessionKeyMoveTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("TonKeyMove-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func reference(_ session: LegacyTonConnectSession) -> LegacyTonConnectSessionKeyReference {
        LegacyTonConnectSessionKeyReference(identifier: session.identifier, publicKey: session.publicKey)
    }

    private func copyFamily(of file: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: file.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(at: source, to: URL(fileURLWithPath: destination.path + suffix))
        }
    }

    func testOldHTTPAndJSSessionsMoveTheirKeysToTheKeychainAndKeepWorking() async throws {
        let file = directory.appendingPathComponent("SubstrateDataModel.sqlite")
        let fixture = try TonConnectFixtureCoreDataService(url: file)
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http")
        let js = try tonConnectTestSession(id: "old-js", clientId: UUID().uuidString, type: "js")
        try fixture.insert(http)
        try fixture.insert(js, missingType: true)
        let before = try fixture.snapshot()
        XCTAssertTrue(before.allSatisfy { $0["privateKey"]?.count == 32 }, "Released rows hold the raw key")

        let sessions = try await LegacyTonConnectStore(service: fixture, keys: keys).sessions()

        XCTAssertEqual(Set(sessions.map(\.identifier)), [http.identifier, js.identifier])
        XCTAssertEqual(sessions.first { $0.identifier == http.identifier }, http)
        XCTAssertEqual(sessions.first { $0.identifier == js.identifier }?.privateKey, js.privateKey)
        let after = try fixture.snapshot()
        for session in [http, js] {
            let row = try XCTUnwrap(after.first { $0["identifier"] == Data(session.identifier.utf8) })
            XCTAssertEqual(row["privateKey"], reference(session).movedColumn, "The row names its Keychain item, marked as moved")
            XCTAssertNotEqual(row["privateKey"], session.privateKey)
            XCTAssertFalse(try XCTUnwrap(row["privateKey"]).range(of: session.privateKey) != nil)
            XCTAssertEqual(keys.items[reference(session).account], session.privateKey)
        }
        XCTAssertEqual(after.map(withoutKeyColumn), before.map(withoutKeyColumn), "No other column changes")
        XCTAssertEqual(keys.items.count, 2, "Only the two session keys are written")

        // A moved session still talks to its original peer with its original key.
        let peer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 9, count: 32))
        let restored = try await LegacyTonConnectStore(service: fixture, keys: keys).sessions()
        let restoredHTTP = try XCTUnwrap(restored.first { $0.identifier == http.identifier })
        let sealed = try restoredHTTP.encrypt(Data("hello".utf8))
        let opened = try NaclBox.open(message: Data(sealed.dropFirst(24)), nonce: Data(sealed.prefix(24)),
                                      publicKey: http.publicKey, secretKey: peer.secretKey)
        XCTAssertEqual(opened, Data("hello".utf8))
        XCTAssertEqual(keys.saveCount, 2, "A moved row is not moved again")
        try fixture.close()
    }

    func testKeychainFailureOrWrongReadBackLeavesTheOldRowUsableAndUnchanged() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http")
        try fixture.insert(http)
        let before = try fixture.snapshot()

        keys.failSaves = errSecInteractionNotAllowed
        let whileUnavailable = try await LegacyTonConnectStore(service: fixture, keys: keys).sessions()
        XCTAssertEqual(whileUnavailable, [http])
        XCTAssertEqual(try fixture.snapshot(), before)

        keys.failSaves = nil
        keys.corruptReads = true
        let withWrongReadBack = try await LegacyTonConnectStore(service: fixture, keys: keys).sessions()
        XCTAssertEqual(withWrongReadBack, [http])
        XCTAssertEqual(try fixture.snapshot(), before, "A key that does not read back is never trusted")

        keys.corruptReads = false
        let moved = try await LegacyTonConnectStore(service: fixture, keys: keys).sessions()
        XCTAssertEqual(moved, [http])
        XCTAssertEqual(try fixture.snapshot().first?["privateKey"], reference(http).movedColumn)
    }

    func testKeychainUnavailableForAMovedSessionIsAnErrorNotAnEmptyList() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession()
        try await store.save(session)
        keys.failLoads = errSecInteractionNotAllowed
        do {
            _ = try await store.sessions()
            XCTFail("A locked Keychain must not look like no sessions")
        } catch {
            guard case LegacyTonConnectError.invalidSession? = error as? LegacyTonConnectError else {
                return XCTFail("Unexpected error \(error)")
            }
        }
        keys.failLoads = nil
        let sessions = try await store.sessions()
        XCTAssertEqual(sessions, [session])
    }

    func testInterruptedMoveKeepsTheRawKeyAndTheNextReadFinishesIt() async throws {
        let file = directory.appendingPathComponent("SubstrateDataModel.sqlite")
        let fixture = try TonConnectFixtureCoreDataService(url: file)
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http")
        let js = try tonConnectTestSession(id: "old-js", clientId: UUID().uuidString, type: "js")
        try fixture.insert(http)
        try fixture.insert(js)
        let before = try fixture.snapshot()

        for boundary in [LegacyTonConnectStore.KeyMigrationBoundary.keyStored, .rowUpdated] {
            struct Interrupted: Error {}
            let interrupted = LegacyTonConnectStore(service: fixture, keys: keys) { reached in
                if reached == boundary { throw Interrupted() }
            }
            let sessions = try await interrupted.sessions()
            XCTAssertEqual(Set(sessions.map(\.identifier)), [http.identifier, js.identifier], "\(boundary)")
            XCTAssertEqual(try fixture.snapshot(), before, "Stopped at \(boundary): the rows keep their raw keys")
        }
        XCTAssertEqual(keys.items.count, 2, "The written items are kept for the next attempt")

        // As after a relaunch: a new store reopened from disk finishes the move with the same items.
        try fixture.close()
        let reopened = try TonConnectFixtureCoreDataService(url: file)
        let sessions = try await LegacyTonConnectStore(service: reopened, keys: keys).sessions()
        XCTAssertEqual(Set(sessions.map(\.identifier)), [http.identifier, js.identifier])
        XCTAssertEqual(Set(try reopened.snapshot().compactMap { $0["privateKey"] }), [reference(http).movedColumn, reference(js).movedColumn])
        XCTAssertEqual(keys.items.count, 2)
        try reopened.close()
    }

    func testRestoredWALAndRetainedStoreRowsAreReadAsLegacyInput() async throws {
        let live = directory.appendingPathComponent("CoreData/SubstrateDataModel.sqlite")
        try FileManager.default.createDirectory(at: live.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fixture = try TonConnectFixtureCoreDataService(url: live)
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http")
        let js = try tonConnectTestSession(id: "old-js", clientId: UUID().uuidString, type: "js")
        try fixture.insert(http)
        try fixture.insert(js, missingType: true)

        // A retained archive taken while the store is open: the rows are in its write-ahead log.
        let preMove = directory.appendingPathComponent("CoreData/SubstrateStoreRetained/\(UUID().uuidString)/SubstrateDataModel.sqlite")
        try copyFamily(of: live, to: preMove)
        XCTAssertTrue(FileManager.default.fileExists(atPath: preMove.path + "-wal"))

        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        _ = try await store.sessions()
        XCTAssertTrue(try fixture.snapshot().allSatisfy { $0["privateKey"]?.count != 32 })
        let postMove = directory.appendingPathComponent("CoreData/SubstrateStoreRetained/\(UUID().uuidString)/SubstrateDataModel.sqlite")
        try copyFamily(of: live, to: postMove)
        try await store.remove(js)
        try fixture.close()

        // Restoring the archive from before the move: its rows hold raw keys. The kept session's key is moved
        // again, to the same item; the disconnected session stays gone, its raw row removed and its key not moved.
        let restoredOld = try TonConnectFixtureCoreDataService(url: preMove)
        let oldSessions = try await LegacyTonConnectStore(service: restoredOld, keys: keys).sessions()
        XCTAssertEqual(oldSessions.map(\.identifier), [http.identifier])
        XCTAssertEqual(try restoredOld.snapshot().compactMap { $0["privateKey"] }, [reference(http).movedColumn])
        XCTAssertNil(keys.items[reference(js).account], "A disconnected session's key never comes back")
        try restoredOld.close()

        // Restoring the archive from after the move: the disconnected session's row is removed as well.
        let restoredNew = try TonConnectFixtureCoreDataService(url: postMove)
        let newSessions = try await LegacyTonConnectStore(service: restoredNew, keys: keys).sessions()
        XCTAssertEqual(newSessions, [http])
        XCTAssertEqual(try restoredNew.snapshot().count, 1)
        // A row whose item is missing for any other reason is hidden but kept.
        try keys.deleteKey(reference: reference(http).account)
        let withoutItem = try await LegacyTonConnectStore(service: restoredNew, keys: keys).sessions()
        XCTAssertTrue(withoutItem.isEmpty)
        XCTAssertEqual(try restoredNew.snapshot().count, 1, "An unreadable row is preserved, never deleted")
        try restoredNew.close()
    }

    func testNewSessionsKeepOnlyAReferenceAndFailClosedWithoutTheKeychain() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession(id: "new-http")

        keys.failSaves = errSecInteractionNotAllowed
        do {
            try await store.save(session)
            XCTFail("A new session is never stored with its raw key")
        } catch {}
        XCTAssertTrue(try fixture.snapshot().isEmpty)
        XCTAssertTrue(keys.items.isEmpty)

        keys.failSaves = nil
        keys.corruptReads = true
        do {
            try await store.save(session)
            XCTFail("A key that does not read back is never referenced")
        } catch {}
        XCTAssertTrue(try fixture.snapshot().isEmpty)
        XCTAssertTrue(keys.items.isEmpty, "The item this save created is removed again")

        keys.corruptReads = false
        try await store.save(session)
        try await store.save(session)
        XCTAssertEqual(try fixture.snapshot().map { $0["privateKey"] }, [reference(session).column])
        XCTAssertEqual(keys.items, [reference(session).account: session.privateKey])
        let sessions = try await store.sessions()
        XCTAssertEqual(sessions, [session])
    }

    func testKeyColumnFormatAndARowNamingAnotherSessionsItem() async throws {
        let session = try tonConnectTestSession()
        let other = try tonConnectTestSession(id: "other")
        XCTAssertEqual(LegacyTonConnectSessionKeyReference.Column(session.privateKey), .legacy(session.privateKey))
        XCTAssertEqual(LegacyTonConnectSessionKeyReference.Column(reference(session).column), .keychain(reference(session).digest))
        XCTAssertEqual(LegacyTonConnectSessionKeyReference.Column(reference(session).movedColumn), .moved(reference(session).digest))
        XCTAssertEqual(LegacyTonConnectSessionKeyReference.Column(reference(session).removingColumn), .removing(reference(session).digest))
        XCTAssertEqual(reference(session).column.count, 38)
        XCTAssertEqual(reference(session).movedColumn.count, 38)
        XCTAssertEqual(Set([reference(session).column, reference(session).movedColumn, reference(session).removingColumn]).count, 3)
        XCTAssertNil(LegacyTonConnectSessionKeyReference.Column(Data(repeating: 1, count: 38)))
        XCTAssertNil(LegacyTonConnectSessionKeyReference.Column(Data(repeating: 1, count: 31)))
        XCTAssertNotEqual(reference(session).account, reference(other).account)
        XCTAssertEqual(reference(session).account.count, 64)

        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        try await store.save(other)
        // A row that points at another session's item is not read with that key.
        try fixture.insertRaw(session, privateKeyColumn: reference(other).column)
        let sessions = try await store.sessions()
        XCTAssertEqual(sessions, [other])
    }

    /// Codex review: a failed save or a disconnect in one context must never remove a key another context committed.
    func testConcurrentSavesAndDisconnectsNeverInterleaveOrLeaveARowWithoutItsKey() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        keys.callDelay = 2000
        let first = LegacyTonConnectStore(service: fixture, keys: keys)
        let second = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession()

        await withTaskGroup(of: Void.self) { group in
            for index in 0 ..< 24 {
                let store = index.isMultiple(of: 2) ? first : second
                group.addTask {
                    if index % 3 == 0 {
                        try? await store.remove(session)
                    } else {
                        try? await store.save(session)
                    }
                }
            }
        }

        XCTAssertFalse(keys.overlapped, "Store operations run one at a time")
        let rows = try fixture.snapshot()
        XCTAssertLessThanOrEqual(rows.count, 1)
        if !rows.isEmpty {
            XCTAssertEqual(keys.items[reference(session).account], session.privateKey, "A committed row always has its key")
        }
        let listed = try await first.sessions()
        XCTAssertEqual(listed, rows.isEmpty ? [] : [session])
    }

    /// Codex review: a disconnect never reports success while the session's key is still in the Keychain.
    func testDisconnectRemovesTheKeyFirstAndFailsClosedWhenItCannot() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession()
        try await store.save(session)

        keys.failDeletes = errSecInteractionNotAllowed
        do {
            try await store.remove(session)
            XCTFail("The disconnect cannot succeed while the key stays")
        } catch {}
        XCTAssertEqual(try fixture.snapshot().first?["privateKey"], reference(session).removingColumn,
                       "The row is durably marked as being removed")
        XCTAssertEqual(keys.items[reference(session).account], session.privateKey)
        let whileKeyStays = try await store.sessions()
        XCTAssertTrue(whileKeyStays.isEmpty, "A session being removed is never listed again")
        XCTAssertEqual(try fixture.snapshot().count, 1, "Kept until its key is gone")

        keys.failDeletes = nil
        let afterRecovery = try await store.sessions()
        XCTAssertTrue(afterRecovery.isEmpty)
        XCTAssertTrue(try fixture.snapshot().isEmpty, "The next read finished the removal")
        XCTAssertNil(keys.items[reference(session).account])
        try await store.remove(session)
    }

    /// Codex review: a released row that is not listed (here an unknown connection type) still loses its raw key.
    func testAReleasedRowThatIsNotListedStillHasItsKeyMoved() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let future = try tonConnectTestSession(id: "future", type: "future")
        try fixture.insert(future)

        let sessions = try await LegacyTonConnectStore(service: fixture, keys: keys).sessions()

        XCTAssertTrue(sessions.isEmpty)
        XCTAssertEqual(try fixture.snapshot().first?["privateKey"], reference(future).movedColumn)
        XCTAssertEqual(keys.items[reference(future).account], future.privateKey)
        XCTAssertEqual(try fixture.snapshot().first?["connectionType"], Data("future".utf8), "The row is otherwise kept as it was")
    }

    /// Codex review: one Keychain error at start must not leave HTTP sessions offline until the next launch.
    func testListenersStartOnceSessionKeysCanBeReadAgain() async throws {
        let session = try tonConnectTestSession()
        let store = TonConnectFlakySessionStore(failures: 2, values: [session])
        let transport = TonConnectFakeTransport()
        let listening = expectation(description: "the HTTP session listens")
        listening.assertForOverFulfill = false
        transport.onListen = { listening.fulfill() }
        let service = LegacyTonConnectService(
            store: store, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()), transport: transport,
            legacyEventId: { nil }, startRetryNanoseconds: 50_000_000
        )

        await service.start(selectedNetwork: "-239")
        await fulfillment(of: [listening], timeout: 5)
        await service.stop()

        XCTAssertGreaterThanOrEqual(store.sessionCalls, 3)
    }

    func testStopEndsTheStartRetries() async throws {
        let store = TonConnectFlakySessionStore(failures: .max, values: [])
        let service = LegacyTonConnectService(
            store: store, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()),
            transport: TonConnectFakeTransport(), legacyEventId: { nil }, startRetryNanoseconds: 20_000_000
        )
        await service.start(selectedNetwork: "-239")
        try await Task.sleep(nanoseconds: 100_000_000)
        await service.stop()
        let afterStop = store.sessionCalls
        XCTAssertGreaterThan(afterStop, 1, "It retried while started")
        try await Task.sleep(nanoseconds: 150_000_000)
        XCTAssertEqual(store.sessionCalls, afterStop, "No retry after stop")
    }

    /// Codex review (round 2): a replayed disconnect is acknowledged only once the session and its key are gone.
    func testDisconnectReplayIsAcknowledgedOnlyAfterTheSessionIsGone() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession()
        try await store.save(session)
        let service = LegacyTonConnectService(
            store: store, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()),
            transport: TonConnectFakeTransport(), legacyEventId: { nil }
        )
        let disconnect = Data(#"{"id":"7","method":"disconnect","params":[]}"#.utf8)

        keys.failDeletes = errSecInteractionNotAllowed
        for _ in 0 ..< 2 {
            do {
                _ = try await service.handle(disconnect, session: session, network: "-239")
                XCTFail("No acknowledgement while the session is still usable")
            } catch {}
        }
        XCTAssertEqual(keys.items[reference(session).account], session.privateKey)

        keys.failDeletes = nil
        let gone = try await store.sessions()
        XCTAssertTrue(gone.isEmpty)
        XCTAssertTrue(try fixture.snapshot().isEmpty)
        XCTAssertNil(keys.items[reference(session).account])
    }

    /// Codex review (round 3): replaying a disconnect that was rejected as malformed changes nothing.
    func testReplayOfARejectedDisconnectKeepsTheSession() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession()
        try await store.save(session)
        let service = LegacyTonConnectService(
            store: store, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()),
            transport: TonConnectFakeTransport(), legacyEventId: { nil }
        )
        let malformed = Data(#"{"id":"8","method":"disconnect","params":["a","b"]}"#.utf8)

        let first = try await service.handle(malformed, session: session, network: "-239")
        let replay = try await service.handle(malformed, session: session, network: "-239")

        XCTAssertEqual(first, replay)
        let listed = try await store.sessions()
        XCTAssertEqual(listed, [session])
        XCTAssertEqual(keys.items[reference(session).account], session.privateKey)
    }

    /// Codex review (round 2): a disconnect whose key went but whose row stayed can be finished later.
    func testADisconnectThatRemovedOnlyTheKeyCanBeFinished() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession()
        let other = try tonConnectTestSession(id: "other")
        try await store.save(session)
        try await store.save(other)
        keys.items[reference(session).account] = nil

        let listed = try await store.sessions()
        XCTAssertEqual(listed, [other], "The half-removed session is not usable")
        try await store.remove(session)

        let rows = try fixture.snapshot()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?["identifier"], Data(other.identifier.utf8))
        // A row that only looks similar is not removed without its key.
        let impostor = LegacyTonConnectSession(
            identifier: other.identifier, walletId: "another-wallet", clientId: other.clientId, appUrl: other.appUrl,
            name: other.name, iconUrl: nil, publicKey: other.publicKey, privateKey: other.privateKey, connectionType: "http"
        )
        do {
            try await store.remove(impostor)
            XCTFail("Another wallet's session must not be removed")
        } catch {}
        XCTAssertEqual(try fixture.snapshot().count, 1)
    }

    /// Codex review (round 2): a discovery still running when stop() or a newer start() comes does nothing after.
    func testADiscoveryThatResumesAfterStopStartsNothing() async throws {
        let session = try tonConnectTestSession()
        let store = TonConnectGatedSessionStore(values: [session])
        let transport = TonConnectFakeTransport()
        var listens = 0
        transport.onListen = { listens += 1 }
        let service = LegacyTonConnectService(
            store: store, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()), transport: transport,
            legacyEventId: { nil }, startRetryNanoseconds: 20_000_000
        )

        let starting = Task { await service.start(selectedNetwork: "-239") }
        try await store.waitForCaller()
        await service.stop()
        store.release(throwing: false)
        await starting.value
        try await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(listens, 0, "No listener after stop()")
        XCTAssertEqual(store.calls, 1, "No retry after stop()")
    }

    /// The real Keychain item: device-only, unlocked-only, not synchronized, and apart from wallet keys.
    func testSessionKeyItemIsDeviceOnlyNotSynchronizedAndApartFromWalletKeys() throws {
        let keychain = LegacyTonConnectSessionKeychain()
        let wallet = Keychain()
        let name = "fearless-tests-tonconnect-" + UUID().uuidString
        let walletKey = Data(repeating: 0xA5, count: 32)
        try wallet.addKey(walletKey, with: name)
        defer {
            try? wallet.deleteKey(for: name)
            try? keychain.deleteKey(reference: name)
        }

        let key = Data(repeating: 0x11, count: 32)
        try keychain.saveKey(key, reference: name)
        XCTAssertEqual(try keychain.loadKey(reference: name), key)
        let attributes = try XCTUnwrap(try keychain.attributes(reference: name))
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
        XCTAssertEqual((attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue ?? false, false)
        XCTAssertEqual(attributes[kSecAttrService as String] as? String, LegacyTonConnectSessionKeychain.service)

        try keychain.saveKey(key, reference: name)
        XCTAssertEqual(try keychain.loadKey(reference: name), key, "Saving the same bytes again is done")
        let replacement = Data(repeating: 0x22, count: 32)
        XCTAssertThrowsError(try keychain.saveKey(replacement, reference: name)) { error in
            XCTAssertEqual(error as? LegacyTonConnectSessionKeyError, .existingKeyDiffers)
        }
        XCTAssertEqual(try keychain.loadKey(reference: name), key, "A stored key is never replaced")
        try keychain.deleteKey(reference: name)
        XCTAssertNil(try keychain.loadKey(reference: name))
        try keychain.deleteKey(reference: name)

        XCTAssertEqual(try wallet.fetchKey(for: name), walletKey, "A wallet key with the same name is untouched")
    }

    func testRetirementRecordIsDeviceOnlyNotSynchronizedAndApartFromSessionKeys() throws {
        let keychain = LegacyTonConnectSessionKeychain()
        let name = "fearless-tests-tonconnect-retired-" + UUID().uuidString
        defer {
            try? keychain.deleteKey(reference: name)
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: LegacyTonConnectSessionKeychain.retiredService,
                kSecAttrAccount as String: name,
                kSecUseDataProtectionKeychain as String: true
            ] as CFDictionary)
        }
        let key = Data(repeating: 0x33, count: 32)
        try keychain.saveKey(key, reference: name)
        XCTAssertFalse(try keychain.isRetired(reference: name))

        try keychain.retire(reference: name)
        try keychain.retire(reference: name)
        XCTAssertTrue(try keychain.isRetired(reference: name))
        let attributes = try XCTUnwrap(try keychain.attributes(reference: name, service: LegacyTonConnectSessionKeychain.retiredService))
        XCTAssertEqual(attributes[kSecAttrAccessible as String] as? String, kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
        XCTAssertEqual((attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue ?? false, false)
        XCTAssertEqual(try keychain.loadKey(reference: name), key, "A retirement record is not the session key")
        try keychain.deleteKey(reference: name)
        XCTAssertTrue(try keychain.isRetired(reference: name), "Deleting the key keeps the record")
    }
}

// MARK: - A save never replaces a stored session key (Codex review, 2026-11-24)

/// An item already stored under a session's reference is never overwritten. The same bytes count as saved; other
/// bytes are refused, and both the item and the row's raw key are kept. Uses the real Keychain (signed build).
final class LegacyTonConnectSessionKeyDuplicateTests: XCTestCase {
    private let keychain = LegacyTonConnectSessionKeychain()
    private var accounts: [String] = []

    override func tearDownWithError() throws {
        for account in accounts {
            try? keychain.deleteKey(reference: account)
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: LegacyTonConnectSessionKeychain.retiredService,
                kSecAttrAccount as String: account,
                kSecUseDataProtectionKeychain as String: true
            ] as CFDictionary)
        }
        accounts = []
        try super.tearDownWithError()
    }

    private func reference(_ session: LegacyTonConnectSession) -> LegacyTonConnectSessionKeyReference {
        LegacyTonConnectSessionKeyReference(identifier: session.identifier, publicKey: session.publicKey)
    }

    /// A session with its own fresh key pair and Keychain item name, cleaned up after the test.
    private func uniqueSession(host: String = "a.example.org") throws -> LegacyTonConnectSession {
        let session = try tonConnectTestSession(id: "duplicate-" + UUID().uuidString, walletId: "legacy-wallet", host: host)
        accounts.append(reference(session).account)
        return session
    }

    private func uniqueAccount() -> String {
        let account = "fearless-tests-tonconnect-duplicate-" + UUID().uuidString
        accounts.append(account)
        return account
    }

    /// Other bytes that make the same key pair: X25519 clears the scalar's three low bits, so only a byte comparison
    /// tells this key from the original.
    private func sameKeyPairOtherBytes(_ key: Data) -> Data {
        var other = key
        other[other.startIndex] ^= 0x01
        return other
    }

    private func protectionClass(_ account: String) throws -> String? {
        try XCTUnwrap(try keychain.attributes(reference: account))[kSecAttrAccessible as String] as? String
    }

    func testFreshSaveAddsADeviceOnlyItem() throws {
        let account = uniqueAccount()
        XCTAssertNil(try keychain.loadKey(reference: account))
        let key = Data(repeating: 0x41, count: 32)

        try keychain.saveKey(key, reference: account)

        XCTAssertEqual(try keychain.loadKey(reference: account), key)
        XCTAssertEqual(try protectionClass(account), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    func testSavingTheSameBytesAgainIsDoneAndOnlyResetsTheProtectionClass() throws {
        let account = uniqueAccount()
        let key = Data(repeating: 0x42, count: 32)
        // The same bytes under a looser protection class, which no release wrote: the save still ends unlocked-only.
        let added = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: LegacyTonConnectSessionKeychain.service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false,
            kSecUseDataProtectionKeychain as String: true,
            kSecValueData as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ] as CFDictionary, nil)
        XCTAssertEqual(added, errSecSuccess)

        try keychain.saveKey(key, reference: account)
        try keychain.saveKey(key, reference: account)

        XCTAssertEqual(try keychain.loadKey(reference: account), key)
        XCTAssertEqual(try protectionClass(account), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    func testSavingOtherBytesNeverReplacesTheStoredKey() throws {
        let account = uniqueAccount()
        let stored = try NaclBox.keyPair().secretKey
        try keychain.saveKey(stored, reference: account)

        for other in [Data(repeating: 0x44, count: 32), sameKeyPairOtherBytes(stored), Data(stored.prefix(31))] {
            XCTAssertThrowsError(try keychain.saveKey(other, reference: account)) { error in
                XCTAssertEqual(error as? LegacyTonConnectSessionKeyError, .existingKeyDiffers)
            }
            XCTAssertEqual(try keychain.loadKey(reference: account), stored, "The stored key is kept as it was")
        }
        XCTAssertEqual(try protectionClass(account), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    }

    /// The upgrade path: a released row's key meets another key stored under the row's reference. Neither is lost:
    /// the item keeps its key, the row keeps its raw key, and the session keeps working with it.
    func testMoveOverAnItemWithOtherBytesKeepsTheItemAndTheRawRow() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let session = try uniqueSession()
        let occupying = sameKeyPairOtherBytes(session.privateKey)
        XCTAssertNotEqual(occupying, session.privateKey)
        XCTAssertEqual(try NaclBox.keyPair(fromSecretKey: occupying).publicKey, session.publicKey,
                       "The stored key would pass a public-key check")
        try keychain.saveKey(occupying, reference: reference(session).account)
        try fixture.insert(session)
        let before = try fixture.snapshot()
        XCTAssertEqual(before.first?["privateKey"], session.privateKey)
        let store = LegacyTonConnectStore(service: fixture, keys: keychain)

        for attempt in 0 ..< 2 {
            let listed = try await store.sessions()
            XCTAssertEqual(listed, [session], "Read \(attempt): listed with the row's own raw key")
            XCTAssertEqual(try fixture.snapshot(), before, "Read \(attempt): the raw row is unchanged")
            XCTAssertEqual(try keychain.loadKey(reference: reference(session).account), occupying,
                           "Read \(attempt): the stored item is not overwritten")
        }
        let waiting = try await store.sessionsToReconnect()
        XCTAssertTrue(waiting.isEmpty, "Nothing moved, so nothing is offered")

        // Saving the same session again tries the same move and keeps both as well.
        try await store.save(session)
        XCTAssertEqual(try fixture.snapshot(), before)
        XCTAssertEqual(try keychain.loadKey(reference: reference(session).account), occupying)

        // Encryption still uses the row's key with the original peer.
        let peer = try NaclBox.keyPair(fromSecretKey: Data(repeating: 9, count: 32))
        let current = try await store.sessions()
        let sealed = try XCTUnwrap(current.first).encrypt(Data("hello".utf8))
        let opened = try NaclBox.open(message: Data(sealed.dropFirst(24)), nonce: Data(sealed.prefix(24)),
                                      publicKey: session.publicKey, secretKey: peer.secretKey)
        XCTAssertEqual(opened, Data("hello".utf8))
        try fixture.close()
    }

    /// An item left with the same bytes (an interrupted move, or a move of a retained copy) completes the move.
    func testMoveOverAnItemWithTheSameBytesCompletesTheMove() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let session = try uniqueSession()
        try keychain.saveKey(session.privateKey, reference: reference(session).account)
        try fixture.insert(session)
        let store = LegacyTonConnectStore(service: fixture, keys: keychain)

        let listed = try await store.sessions()

        XCTAssertEqual(listed, [session])
        XCTAssertEqual(try fixture.snapshot().first?["privateKey"], reference(session).movedColumn)
        XCTAssertEqual(try keychain.loadKey(reference: reference(session).account), session.privateKey)
        let waiting = try await store.sessionsToReconnect()
        XCTAssertEqual(waiting, [session], "A moved key is offered for reconnection as before")
        try fixture.close()
    }

    /// New sessions: a fresh item is saved; an item with the same bytes (a save whose row was never written) is
    /// used; an item with other bytes refuses the save, which writes no row and leaves the item in place.
    func testNewSessionSavesFreshOrEqualItemsAndNeverOverwritesAnother() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let store = LegacyTonConnectStore(service: fixture, keys: keychain)

        let fresh = try uniqueSession(host: "a.example.org")
        XCTAssertNil(try keychain.loadKey(reference: reference(fresh).account))
        try await store.save(fresh)
        XCTAssertEqual(try fixture.snapshot().map { $0["privateKey"] }, [reference(fresh).column])
        XCTAssertEqual(try keychain.loadKey(reference: reference(fresh).account), fresh.privateKey)

        let resumed = try uniqueSession(host: "b.example.org")
        try keychain.saveKey(resumed.privateKey, reference: reference(resumed).account)
        try await store.save(resumed)
        XCTAssertEqual(try keychain.loadKey(reference: reference(resumed).account), resumed.privateKey)

        let blocked = try uniqueSession(host: "c.example.org")
        let occupying = try NaclBox.keyPair().secretKey
        try keychain.saveKey(occupying, reference: reference(blocked).account)
        do {
            try await store.save(blocked)
            XCTFail("A new session never overwrites a stored key")
        } catch {
            XCTAssertEqual(error as? LegacyTonConnectSessionKeyError, .existingKeyDiffers)
        }
        XCTAssertEqual(try keychain.loadKey(reference: reference(blocked).account), occupying,
                       "The item is neither replaced nor removed")

        let rows = try fixture.snapshot()
        XCTAssertEqual(Set(rows.compactMap { $0["privateKey"] }), [reference(fresh).column, reference(resumed).column])
        let listed = try await store.sessions()
        XCTAssertEqual(Set(listed.map(\.identifier)), [fresh.identifier, resumed.identifier])
        XCTAssertEqual(listed.first { $0.identifier == resumed.identifier }, resumed)
        try fixture.close()
    }

    /// The store keeps both keys with any key store that refuses to overwrite, the in-memory one included.
    func testAMoveThatMeetsAnotherStoredKeyKeepsBothWithTheInMemoryKeyStore() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let session = try tonConnectTestSession(id: "occupied", walletId: "legacy-wallet", host: "a.example.org")
        let occupying = Data(repeating: 0x5A, count: 32)
        keys.items[reference(session).account] = occupying
        try fixture.insert(session)
        let before = try fixture.snapshot()

        let listed = try await LegacyTonConnectStore(service: fixture, keys: keys).sessions()

        XCTAssertEqual(listed, [session])
        XCTAssertEqual(try fixture.snapshot(), before)
        XCTAssertEqual(keys.items, [reference(session).account: occupying])
        XCTAssertEqual(keys.saveCount, 0)
    }
}

// MARK: - Retiring transport keys an older version kept in SQLite (MoldyRoost audit finding 5)

private func tonConnectTestSession(
    id: String, walletId: String, host: String, type: String = "http", secretKey: Data? = nil
) throws -> LegacyTonConnectSession {
    let walletPair = try secretKey.map { try NaclBox.keyPair(fromSecretKey: $0) } ?? NaclBox.keyPair()
    let peerPair = try NaclBox.keyPair(fromSecretKey: Data(repeating: 9, count: 32))
    return LegacyTonConnectSession(
        identifier: id, walletId: walletId,
        clientId: type == "js" ? UUID().uuidString : peerPair.publicKey.map { String(format: "%02x", $0) }.joined(),
        appUrl: URL(string: "https://\(host)/app")!, name: "Application at \(host)", iconUrl: nil,
        publicKey: walletPair.publicKey, privateKey: walletPair.secretKey, connectionType: type
    )
}

private final class TonConnectHangingTransport: LegacyTonConnectBridgeTransporting {
    private let lock = NSLock()
    private var inFlight = 0
    private var cancelled = 0
    private var mostInFlight = 0
    var cancelledSends: Int { lock.lock(); defer { lock.unlock() }; return cancelled }
    var maximumInFlight: Int { lock.lock(); defer { lock.unlock() }; return mostInFlight }
    func manifest(at url: URL) async throws -> LegacyTonConnectManifest { .init(url: url, name: "Fixture", iconUrl: nil) }
    func send(_: Data, session _: LegacyTonConnectSession, bridge _: URL, topic _: String) async throws {
        lock.lock()
        inFlight += 1
        mostInFlight = max(mostInFlight, inFlight)
        lock.unlock()
        defer { lock.lock(); inFlight -= 1; lock.unlock() }
        do {
            try await Task.sleep(nanoseconds: 60_000_000_000)
        } catch {
            lock.lock()
            cancelled += 1
            lock.unlock()
            throw error
        }
    }
    func listen(session _: LegacyTonConnectSession, context _: LegacyTonConnectSessionContext, receive _: @escaping (Data, String?) async throws -> Void) async throws {
        throw URLError(.notConnectedToInternet)
    }
}

/// Keeps every message, from any thread.
private final class TonConnectRecordingLogger: LoggerProtocol {
    private let lock = NSLock()
    private var recorded: [String] = []
    var warnings: [String] { lock.lock(); defer { lock.unlock() }; return recorded }

    private func record(_ message: String) {
        lock.lock()
        recorded.append(message)
        lock.unlock()
    }

    func verbose(message _: String, file _: String, function _: String, line _: Int) {}
    func debug(message _: String, file _: String, function _: String, line _: Int) {}
    func info(message _: String, file _: String, function _: String, line _: Int) {}
    func warning(message: String, file _: String, function _: String, line _: Int) { record(message) }
    func error(message: String, file _: String, function _: String, line _: Int) { record(message) }
    func customError(error: Error, file _: String, function _: String, line _: Int) { record("\(error)") }
}

/// Stands in for iOS background time: records each request and each end, and lets a test run it out.
private final class TonConnectBackgroundTimeRecorder {
    private let lock = NSLock()
    private var expiries: [() -> Void] = []
    private var ends = 0
    var requested: Int { lock.lock(); defer { lock.unlock() }; return expiries.count }
    var ended: Int { lock.lock(); defer { lock.unlock() }; return ends }

    func request(expired: @escaping () -> Void) -> () -> Void {
        lock.lock()
        expiries.append(expired)
        lock.unlock()
        // Every call counts: an end called twice shows as more ends than requests.
        return { [self] in
            lock.lock()
            ends += 1
            lock.unlock()
        }
    }

    /// iOS ends the time: each handler runs, as UIKit's expiration handler would.
    func expireAll() {
        lock.lock()
        let all = expiries
        lock.unlock()
        all.forEach { $0() }
    }
}

/// Counts notifications from any thread.
private final class TonConnectPostCounter {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.lock(); defer { lock.unlock() }; return count }
    func increment() { lock.lock(); count += 1; lock.unlock() }
}

/// A bridge whose send ignores cancellation until the test releases it.
private final class TonConnectStuckTransport: LegacyTonConnectBridgeTransporting {
    private let lock = NSLock()
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var released = false
    private var sendCount = 0
    var onSend: ((LegacyTonConnectSession) -> Void)?
    var sends: Int { lock.lock(); defer { lock.unlock() }; return sendCount }

    func manifest(at url: URL) async throws -> LegacyTonConnectManifest { .init(url: url, name: "Fixture", iconUrl: nil) }
    func send(_: Data, session: LegacyTonConnectSession, bridge _: URL, topic _: String) async throws {
        onSend?(session)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            sendCount += 1
            if released {
                lock.unlock()
                continuation.resume()
                return
            }
            waiters.append(continuation)
            lock.unlock()
        }
    }
    func listen(session _: LegacyTonConnectSession, context _: LegacyTonConnectSessionContext, receive _: @escaping (Data, String?) async throws -> Void) async throws {
        throw URLError(.notConnectedToInternet)
    }
    func release() {
        lock.lock()
        released = true
        let pending = waiters
        waiters = []
        lock.unlock()
        pending.forEach { $0.resume() }
    }
}

final class LegacyTonConnectReconnectStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("TonReconnect-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func reference(_ session: LegacyTonConnectSession) -> LegacyTonConnectSessionKeyReference {
        LegacyTonConnectSessionKeyReference(identifier: session.identifier, publicKey: session.publicKey)
    }

    private func column(of session: LegacyTonConnectSession, in fixture: TonConnectFixtureCoreDataService) throws -> Data? {
        try fixture.snapshot().first { $0["identifier"] == Data(session.identifier.utf8) }?["privateKey"]
    }

    func testAMovedKeyIsMarkedInTheSameSaveAndWaitsDurablyUntilTheUserAnswers() async throws {
        let file = directory.appendingPathComponent("SubstrateDataModel.sqlite")
        let fixture = try TonConnectFixtureCoreDataService(url: file)
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http", walletId: "legacy-wallet", host: "a.example.org")
        let js = try tonConnectTestSession(id: "old-js", walletId: "legacy-wallet", host: "b.example.org", type: "js")
        let fresh = try tonConnectTestSession(id: "new-http", walletId: "legacy-wallet", host: "c.example.org")
        try fixture.insert(http)
        try fixture.insert(js, missingType: true)
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        try await store.save(fresh)

        let waiting = try await store.sessionsToReconnect()
        XCTAssertEqual(Set(waiting.map(\.identifier)), [http.identifier, js.identifier], "Only keys moved out of raw rows wait")
        XCTAssertEqual(waiting.first { $0.identifier == http.identifier }, http)
        XCTAssertEqual(try column(of: http, in: fixture), reference(http).movedColumn)
        XCTAssertEqual(try column(of: js, in: fixture), reference(js).movedColumn)
        XCTAssertEqual(try column(of: fresh, in: fixture), reference(fresh).column, "A session made here never held a raw key")
        let listed = try await store.sessions()
        XCTAssertEqual(Set(listed.map(\.identifier)), [http.identifier, js.identifier, fresh.identifier])
        XCTAssertEqual(listed.first { $0.identifier == http.identifier }, http, "A waiting session works exactly as before")

        // The mark is in the database: a relaunch still offers it.
        try fixture.close()
        let reopened = try TonConnectFixtureCoreDataService(url: file)
        let reopenedStore = LegacyTonConnectStore(service: reopened, keys: keys)
        let afterRelaunch = try await reopenedStore.sessionsToReconnect()
        XCTAssertEqual(Set(afterRelaunch.map(\.identifier)), [http.identifier, js.identifier])

        // A row with this identifier but another key is not this session's answer.
        let impostor = LegacyTonConnectSession(
            identifier: http.identifier, walletId: http.walletId, clientId: http.clientId, appUrl: http.appUrl, name: http.name,
            iconUrl: nil, publicKey: fresh.publicKey, privateKey: fresh.privateKey, connectionType: http.connectionType
        )
        let before = try reopened.snapshot()
        try await reopenedStore.finishReconnectOffer(for: [impostor])
        XCTAssertEqual(try reopened.snapshot(), before)

        try await reopenedStore.finishReconnectOffer(for: [http])
        XCTAssertEqual(try column(of: http, in: reopened), reference(http).column, "Answered: the same item, no longer waiting")
        XCTAssertEqual(try column(of: js, in: reopened), reference(js).movedColumn, "Another session still waits")
        XCTAssertEqual(try reopened.snapshot().map(withoutKeyColumn), before.map(withoutKeyColumn), "Nothing else changes")
        let stillWaiting = try await reopenedStore.sessionsToReconnect()
        XCTAssertEqual(stillWaiting.map(\.identifier), [js.identifier])
        let afterAnswer = try await reopenedStore.sessions()
        XCTAssertEqual(afterAnswer.first { $0.identifier == http.identifier }, http)
        XCTAssertEqual(keys.items[reference(http).account], http.privateKey, "The key is never touched")
        XCTAssertEqual(keys.items.count, 3)

        try await reopenedStore.finishReconnectOffer(for: [http])
        XCTAssertEqual(try column(of: http, in: reopened), reference(http).column, "Answering twice changes nothing")
        try reopened.close()
    }

    func testAnInterruptedMoveIsNeitherMarkedNorOfferedAndTheFinishedMoveIs() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http", walletId: "legacy-wallet", host: "a.example.org")
        try fixture.insert(http)
        let before = try fixture.snapshot()

        for boundary in [LegacyTonConnectStore.KeyMigrationBoundary.keyStored, .rowUpdated] {
            struct Interrupted: Error {}
            let interrupted = LegacyTonConnectStore(service: fixture, keys: keys) { reached in
                if reached == boundary { throw Interrupted() }
            }
            let waiting = try await interrupted.sessionsToReconnect()
            XCTAssertTrue(waiting.isEmpty, "Stopped at \(boundary): the row still holds its raw key and is moved later")
            XCTAssertEqual(try fixture.snapshot(), before)
        }
        keys.failSaves = errSecInteractionNotAllowed
        let whileUnavailable = try await LegacyTonConnectStore(service: fixture, keys: keys).sessionsToReconnect()
        XCTAssertTrue(whileUnavailable.isEmpty)

        keys.failSaves = nil
        let waiting = try await LegacyTonConnectStore(service: fixture, keys: keys).sessionsToReconnect()
        XCTAssertEqual(waiting, [http])
        XCTAssertEqual(try fixture.snapshot().first?["privateKey"], reference(http).movedColumn)
    }

    func testAWaitingSessionDisconnectsLikeAnyOtherAndAnInterruptedDisconnectIsFinished() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let first = try tonConnectTestSession(id: "first", walletId: "legacy-wallet", host: "a.example.org")
        let second = try tonConnectTestSession(id: "second", walletId: "legacy-wallet", host: "b.example.org")
        try fixture.insert(first)
        try fixture.insert(second)
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let waiting = try await store.sessionsToReconnect()
        XCTAssertEqual(waiting.count, 2)

        try await store.remove(first)
        XCTAssertNil(try column(of: first, in: fixture))
        XCTAssertNil(keys.items[reference(first).account])
        let remaining = try await store.sessionsToReconnect()
        XCTAssertEqual(remaining, [second])

        // The key went but the row stayed (an earlier disconnect cut short): it is finished, not left waiting.
        try keys.deleteKey(reference: reference(second).account)
        let none = try await store.sessionsToReconnect()
        XCTAssertTrue(none.isEmpty, "A row whose key is gone is not a session")
        try await store.remove(second)
        XCTAssertTrue(try fixture.snapshot().isEmpty)
    }

    func testARestoredArchiveFromBeforeTheMoveWaitsAgain() async throws {
        let live = directory.appendingPathComponent("CoreData/SubstrateDataModel.sqlite")
        try FileManager.default.createDirectory(at: live.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fixture = try TonConnectFixtureCoreDataService(url: live)
        let keys = TonConnectFakeSessionKeys()
        let http = try tonConnectTestSession(id: "old-http", walletId: "legacy-wallet", host: "a.example.org")
        try fixture.insert(http)
        try fixture.close()
        let archive = directory.appendingPathComponent("CoreData/SubstrateStoreRetained/\(UUID().uuidString)/SubstrateDataModel.sqlite")
        try FileManager.default.createDirectory(at: archive.deletingLastPathComponent(), withIntermediateDirectories: true)
        for suffix in ["", "-wal", "-shm"] where FileManager.default.fileExists(atPath: live.path + suffix) {
            try FileManager.default.copyItem(atPath: live.path + suffix, toPath: archive.path + suffix)
        }

        let reopened = try TonConnectFixtureCoreDataService(url: live)
        let store = LegacyTonConnectStore(service: reopened, keys: keys)
        _ = try await store.sessionsToReconnect()
        try await store.finishReconnectOffer(for: [http])
        let answered = try await store.sessionsToReconnect()
        XCTAssertTrue(answered.isEmpty)
        try reopened.close()

        // The archive still holds the raw key: once restored, the key is moved again and the offer comes back.
        let restored = try TonConnectFixtureCoreDataService(url: archive)
        let again = try await LegacyTonConnectStore(service: restored, keys: keys).sessionsToReconnect()
        XCTAssertEqual(again, [http])
        try restored.close()
    }

    func testADisconnectedSessionNeverComesBackFromAnArchiveOrALateSave() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let session = try tonConnectTestSession(id: "retired", walletId: "legacy-wallet", host: "a.example.org")
        try await store.save(session)
        try await store.remove(session)
        XCTAssertEqual(keys.retired, [reference(session).account], "The disconnect is recorded on this device")
        XCTAssertTrue(keys.items.isEmpty)

        // A connection approved before the disconnect and saved after it cannot store the session again.
        do {
            try await store.save(session)
            XCTFail("A disconnected session is never saved again")
        } catch {}
        XCTAssertTrue(try fixture.snapshot().isEmpty)
        XCTAssertTrue(keys.items.isEmpty)

        // Its raw row restored from an archive is removed, not moved, listed or offered.
        try fixture.insert(session)
        let saves = keys.saveCount
        let listed = try await store.sessions()
        XCTAssertTrue(listed.isEmpty)
        XCTAssertTrue(try fixture.snapshot().isEmpty, "The restored row and its raw key are removed")
        XCTAssertEqual(keys.saveCount, saves, "Its key is never written to the Keychain again")
        let waiting = try await store.sessionsToReconnect()
        XCTAssertTrue(waiting.isEmpty)

        // A new pairing with the same application is a new identity and works.
        let fresh = try tonConnectTestSession(id: "fresh", walletId: "legacy-wallet", host: "a.example.org")
        try await store.save(fresh)
        let afterPairing = try await store.sessions()
        XCTAssertEqual(afterPairing, [fresh])
    }

    func testADisconnectIsRecordedBeforeAnythingElseAndACutShortOneIsRecordedWhenFinished() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let first = try tonConnectTestSession(id: "first", walletId: "legacy-wallet", host: "a.example.org")
        try fixture.insert(first)
        _ = try await store.sessions()
        let before = try fixture.snapshot()

        keys.failRetires = errSecInteractionNotAllowed
        do {
            try await store.remove(first)
            XCTFail("A disconnect that cannot be recorded does not start")
        } catch {}
        XCTAssertEqual(try fixture.snapshot(), before, "Nothing changed")
        XCTAssertEqual(keys.items[reference(first).account], first.privateKey)
        let stillWaiting = try await store.sessionsToReconnect()
        XCTAssertEqual(stillWaiting, [first])

        // A disconnect cut short by an earlier version (marked, never recorded) is recorded as it is finished.
        keys.failRetires = nil
        let second = try tonConnectTestSession(id: "second", walletId: "legacy-wallet", host: "b.example.org")
        try fixture.insertRaw(second, privateKeyColumn: reference(second).removingColumn)
        try keys.saveKey(second.privateKey, reference: reference(second).account)
        let listed = try await store.sessions()
        XCTAssertEqual(listed, [first])
        XCTAssertTrue(keys.retired.contains(reference(second).account))
        XCTAssertNil(keys.items[reference(second).account])
        XCTAssertEqual(try fixture.snapshot().count, 1)
    }

    func testAnUnreadableRetirementRecordStopsMovesListingAndSavesUntilItCanBeRead() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let store = LegacyTonConnectStore(service: fixture, keys: keys)
        let raw = try tonConnectTestSession(id: "raw", walletId: "legacy-wallet", host: "a.example.org")
        let fresh = try tonConnectTestSession(id: "fresh", walletId: "legacy-wallet", host: "b.example.org")
        try fixture.insert(raw)
        let before = try fixture.snapshot()

        keys.failRetiredLookups = errSecInteractionNotAllowed
        do {
            _ = try await store.sessions()
            XCTFail("An unreadable record is an error, not an empty list")
        } catch {}
        do {
            _ = try await store.sessionsToReconnect()
            XCTFail("Nothing is offered while it cannot be told apart from a disconnected session")
        } catch {}
        do {
            try await store.save(fresh)
            XCTFail("Nothing is saved while the record cannot be read")
        } catch {}
        XCTAssertEqual(try fixture.snapshot(), before, "The raw row is neither moved nor removed")
        XCTAssertTrue(keys.items.isEmpty)

        keys.failRetiredLookups = nil
        let waiting = try await store.sessionsToReconnect()
        XCTAssertEqual(waiting, [raw])
        try await store.save(fresh)
        let listed = try await store.sessions()
        XCTAssertEqual(Set(listed.map(\.identifier)), [raw.identifier, fresh.identifier])
    }

    /// The in-place scrub the store relies on: Apple's SQLite zeroes a replaced cell (`secure_delete`, FAST or ON).
    func testTheMoveLeavesNoRawKeyInTheClosedDatabaseFile() async throws {
        var library: OpaquePointer?
        XCTAssertEqual(sqlite3_open(":memory:", &library), SQLITE_OK)
        var pragma: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(library, "PRAGMA secure_delete", -1, &pragma, nil), SQLITE_OK)
        XCTAssertEqual(sqlite3_step(pragma), SQLITE_ROW)
        XCTAssertNotEqual(sqlite3_column_int(pragma, 0), 0, "secure_delete is on by default in the system SQLite")
        sqlite3_finalize(pragma)
        sqlite3_close(library)

        let file = directory.appendingPathComponent("SubstrateDataModel.sqlite")
        let http = try tonConnectTestSession(id: "old-http", walletId: "legacy-wallet", host: "a.example.org")
        let written = try TonConnectFixtureCoreDataService(url: file)
        try written.insert(http)
        try written.close()
        func family() throws -> Data {
            try ["", "-wal", "-journal"].reduce(into: Data()) { result, suffix in
                let path = file.path + suffix
                if FileManager.default.fileExists(atPath: path) {
                    result.append(try Data(contentsOf: URL(fileURLWithPath: path)))
                }
            }
        }
        XCTAssertNotNil(try family().range(of: http.privateKey), "The released row's raw key is on disk")

        let reopened = try TonConnectFixtureCoreDataService(url: file)
        let keys = TonConnectFakeSessionKeys()
        _ = try await LegacyTonConnectStore(service: reopened, keys: keys).sessions()
        try reopened.close()
        XCTAssertNil(try family().range(of: http.privateKey), "Moving the key leaves no copy in the live database")
        XCTAssertEqual(keys.items[reference(http).account], http.privateKey)
    }
}

final class LegacyTonConnectReconnectCoordinatorTests: XCTestCase {
    private func reference(_ session: LegacyTonConnectSession) -> LegacyTonConnectSessionKeyReference {
        LegacyTonConnectSessionKeyReference(identifier: session.identifier, publicKey: session.publicKey)
    }

    private func makeCoordinator(
        fixture: TonConnectFixtureCoreDataService,
        keys: TonConnectFakeSessionKeys,
        transport: LegacyTonConnectBridgeTransporting,
        enabled: Bool = true,
        noticeNanoseconds: UInt64 = 5_000_000_000,
        logger: LoggerProtocol = TonConnectRecordingLogger(),
        backgroundTime: @escaping LegacyTonConnectCoordinator.BackgroundTimeRequest = LegacyTonConnectBackgroundTime.request
    ) throws -> LegacyTonConnectCoordinator {
        let walletKeys = TonConnectFixtureKeychain()
        let wallet = try tonConnectTestWallet(walletKeys)
        try fixture.insertBridge(network: "-239", url: URL(string: "https://bridge.example.org/bridge")!)
        return LegacyTonConnectCoordinator(
            store: LegacyTonConnectStore(service: fixture, keys: keys), transport: transport,
            replies: .init(keystore: walletKeys), keystore: walletKeys, selectedWallet: { wallet },
            networkSelection: { "-239" }, walletLoader: { _ in wallet }, isEnabled: { enabled },
            disconnectNoticeNanoseconds: noticeNanoseconds, logger: logger, requestBackgroundTime: backgroundTime
        )
    }

    @MainActor
    func testOnlyTheSelectedWalletsBridgeSessionsAreOfferedAndKeepingThemEndsTheOffer() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let transport = TonConnectFakeTransport()
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let browser = try tonConnectTestSession(id: "browser", walletId: "legacy-wallet", host: "b.example.org", type: "js")
        let otherWallet = try tonConnectTestSession(id: "other", walletId: "another-wallet", host: "c.example.org")
        for session in [bridge, browser, otherWallet] {
            try fixture.insert(session)
        }
        let coordinator = try makeCoordinator(fixture: fixture, keys: keys, transport: transport)

        let offered = try await coordinator.sessionsToReconnect()
        XCTAssertEqual(offered, [bridge], "An in-app browser session never uses its key; another wallet's waits for its own list")

        try await coordinator.keepWithoutReconnecting(offered)
        let afterKeeping = try await coordinator.sessionsToReconnect()
        XCTAssertTrue(afterKeeping.isEmpty)
        let listed = try await coordinator.selectedSessions()
        XCTAssertEqual(Set(listed.map(\.identifier)), [bridge.identifier, browser.identifier])
        XCTAssertEqual(listed.first { $0.identifier == bridge.identifier }, bridge, "Keeping changes nothing about the session")
        XCTAssertTrue(transport.sent.isEmpty, "Keeping tells nobody anything")
        let otherStillWaits = try await LegacyTonConnectStore(service: fixture, keys: keys).sessionsToReconnect()
        XCTAssertEqual(Set(otherStillWaits.map(\.identifier)), [browser.identifier, otherWallet.identifier])
    }

    @MainActor
    func testReconnectingTellsEachApplicationThenRemovesItsSessionAndKey() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let transport = TonConnectFakeTransport()
        let first = try tonConnectTestSession(id: "first", walletId: "legacy-wallet", host: "a.example.org")
        let second = try tonConnectTestSession(id: "second", walletId: "legacy-wallet", host: "b.example.org")
        try fixture.insert(first)
        try fixture.insert(second)
        let coordinator = try makeCoordinator(fixture: fixture, keys: keys, transport: transport)
        let offered = try await coordinator.sessionsToReconnect()
        XCTAssertEqual(Set(offered.map(\.identifier)), [first.identifier, second.identifier])

        try await coordinator.reconnect(offered)
        await coordinator.waitForDisconnectNotices()

        XCTAssertEqual(transport.sent.map { $0.1.identifier }.sorted(), offered.map(\.identifier).sorted(), "Each application is told, once")
        for (data, session, bridge, topic) in transport.sent {
            XCTAssertEqual(topic, "disconnect")
            XCTAssertEqual(bridge, URL(string: "https://bridge.example.org/bridge")!)
            let event = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(event["event"] as? String, "disconnect")
            let id = try XCTUnwrap(event["id"] as? UInt64)
            XCTAssertEqual(id, LegacyTonConnectCoordinator.disconnectEventId)
            XCTAssertEqual(id, 9_007_199_254_740_991, "Number.MAX_SAFE_INTEGER: exact in JavaScript")
            XCTAssertEqual(UInt64(Double(id)), id)
            // @tonconnect/sdk drops a wallet event unless its id is above the last one, and connect events here use
            // Unix seconds: even one sent in the same second, or after the clock moved back, is below it.
            XCTAssertGreaterThan(id, UInt64(Date().timeIntervalSince1970) + 1_000_000_000_000)
            XCTAssertEqual((event["payload"] as? [String: Any])?.isEmpty, true)
            XCTAssertNil(keys.items[reference(session).account], "The retired key is gone")
        }
        XCTAssertTrue(try fixture.snapshot().isEmpty)
        let remaining = try await coordinator.selectedSessions()
        XCTAssertTrue(remaining.isEmpty)
    }

    @MainActor
    func testAnUnreachableOrSlowBridgeNeverKeepsTheSessionAndAPausedOneIsNotContacted() async throws {
        let failing = TonConnectFakeTransport()
        failing.failSends = true
        let offline = try tonConnectTestSession(id: "offline", walletId: "legacy-wallet", host: "a.example.org")
        let offlineFixture = try TonConnectFixtureCoreDataService()
        try offlineFixture.insert(offline)
        let offlineKeys = TonConnectFakeSessionKeys()
        let offlineLogger = TonConnectRecordingLogger()
        let offlineCoordinator = try makeCoordinator(fixture: offlineFixture, keys: offlineKeys, transport: failing, logger: offlineLogger)
        try await offlineCoordinator.reconnect(offlineCoordinator.sessionsToReconnect())
        await offlineCoordinator.waitForDisconnectNotices()
        XCTAssertTrue(try offlineFixture.snapshot().isEmpty)
        XCTAssertTrue(offlineKeys.items.isEmpty)
        XCTAssertEqual(offlineLogger.warnings, ["A TON Connect application was not told about a disconnect; the session is removed"])

        let hanging = TonConnectHangingTransport()
        let slow = try tonConnectTestSession(id: "slow", walletId: "legacy-wallet", host: "b.example.org")
        let slower = try tonConnectTestSession(id: "slower", walletId: "legacy-wallet", host: "d.example.org")
        let slowFixture = try TonConnectFixtureCoreDataService()
        try slowFixture.insert(slow)
        try slowFixture.insert(slower)
        let slowKeys = TonConnectFakeSessionKeys()
        let slowCoordinator = try makeCoordinator(
            fixture: slowFixture, keys: slowKeys, transport: hanging, noticeNanoseconds: 3_000_000_000
        )
        let started = Date()
        try await slowCoordinator.reconnect(slowCoordinator.sessionsToReconnect())
        XCTAssertEqual(slowCoordinator.disconnectNoticesInFlight, 1, "The answer did not wait for the notices")
        await slowCoordinator.waitForDisconnectNotices()
        XCTAssertLessThan(Date().timeIntervalSince(started), 30, "The notices take a bounded time")
        XCTAssertEqual(slowCoordinator.disconnectNoticesInFlight, 0)
        XCTAssertEqual(hanging.maximumInFlight, 2, "Both notices go out together: one wait, not one each")
        // The answer does not wait for the cancelled notices to end; they end soon after.
        for _ in 0 ..< 500 where hanging.cancelledSends < 2 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(hanging.cancelledSends, 2, "Unanswered notices are cancelled")
        XCTAssertTrue(try slowFixture.snapshot().isEmpty)
        XCTAssertTrue(slowKeys.items.isEmpty)

        let paused = TonConnectFakeTransport()
        let quiet = try tonConnectTestSession(id: "quiet", walletId: "legacy-wallet", host: "c.example.org")
        let pausedFixture = try TonConnectFixtureCoreDataService()
        try pausedFixture.insert(quiet)
        let pausedLogger = TonConnectRecordingLogger()
        let pausedCoordinator = try makeCoordinator(
            fixture: pausedFixture, keys: TonConnectFakeSessionKeys(), transport: paused, enabled: false, logger: pausedLogger
        )
        try await pausedCoordinator.reconnect(pausedCoordinator.sessionsToReconnect())
        XCTAssertEqual(pausedCoordinator.disconnectNoticesInFlight, 0, "Nothing is sent, so nothing is in flight")
        await pausedCoordinator.waitForDisconnectNotices()
        XCTAssertTrue(paused.sent.isEmpty, "A paused TON Connect sends nothing")
        XCTAssertTrue(try pausedFixture.snapshot().isEmpty, "The user's disconnect still happens")
        XCTAssertEqual(
            pausedLogger.warnings,
            ["TON Connect is paused: a disconnect notice to 1 application(s) was not sent"],
            "Skipping the notice is logged, not silent"
        )

        // The swipe path logs the same way.
        let swiped = try tonConnectTestSession(id: "swiped", walletId: "legacy-wallet", host: "e.example.org")
        try pausedFixture.insert(swiped)
        _ = try await pausedCoordinator.selectedSessions()
        try await pausedCoordinator.disconnect(swiped)
        XCTAssertEqual(pausedCoordinator.disconnectNoticesInFlight, 0, "Nothing is sent later either")
        await pausedCoordinator.waitForDisconnectNotices()
        XCTAssertTrue(paused.sent.isEmpty)
        XCTAssertEqual(pausedLogger.warnings.count, 2)
        XCTAssertEqual(pausedLogger.warnings.last, pausedLogger.warnings.first)
    }

    @MainActor
    func testEverySessionIsRemovedBeforeAnyNoticeAndAStuckBridgeNeverHoldsTheAnswerUp() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let transport = TonConnectStuckTransport()
        defer { transport.release() }
        let first = try tonConnectTestSession(id: "first", walletId: "legacy-wallet", host: "a.example.org")
        let second = try tonConnectTestSession(id: "second", walletId: "legacy-wallet", host: "b.example.org")
        try fixture.insert(first)
        try fixture.insert(second)
        let lock = NSLock()
        var rowsAtSend: [Int] = []
        transport.onSend = { _ in
            let rows = (try? fixture.snapshot().count) ?? -1
            lock.lock()
            rowsAtSend.append(rows)
            lock.unlock()
        }
        let coordinator = try makeCoordinator(fixture: fixture, keys: keys, transport: transport, noticeNanoseconds: 300_000_000)
        let offered = try await coordinator.sessionsToReconnect()

        let started = Date()
        try await coordinator.reconnect(offered)
        await coordinator.waitForDisconnectNotices()

        XCTAssertLessThan(Date().timeIntervalSince(started), 20, "A send that ignores cancellation is still given up")
        XCTAssertTrue(try fixture.snapshot().isEmpty)
        XCTAssertTrue(keys.items.isEmpty, "Both retired keys are gone")
        XCTAssertEqual(keys.retired.count, 2)
        lock.lock()
        let observed = rowsAtSend
        lock.unlock()
        XCTAssertEqual(observed, [0, 0], "Each application is told only after every selected session was removed")

        // The swipe path: removed first as well.
        let third = try tonConnectTestSession(id: "third", walletId: "legacy-wallet", host: "c.example.org")
        try fixture.insert(third)
        _ = try await coordinator.selectedSessions()
        let swipeStarted = Date()
        try await coordinator.disconnect(third)
        await coordinator.waitForDisconnectNotices()
        XCTAssertLessThan(Date().timeIntervalSince(swipeStarted), 20)
        XCTAssertTrue(try fixture.snapshot().isEmpty)
        lock.lock()
        let observedAfterSwipe = rowsAtSend
        lock.unlock()
        XCTAssertEqual(observedAfterSwipe, [0, 0, 0])
    }

    /// Review minor (2026-11-24): the user never waits for a bridge. Both disconnect paths return once the sessions
    /// are removed here, and the notices finish in the background.
    @MainActor
    func testADisconnectReturnsOnceRemovedAndItsNoticeFinishesInTheBackground() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let transport = TonConnectStuckTransport()
        defer { transport.release() }
        let offered = try tonConnectTestSession(id: "offered", walletId: "legacy-wallet", host: "a.example.org")
        let swiped = try tonConnectTestSession(id: "swiped", walletId: "legacy-wallet", host: "b.example.org")
        try fixture.insert(offered)
        try fixture.insert(swiped)
        let backgroundTime = TonConnectBackgroundTimeRecorder()
        // A deadline far beyond the test: only the bridge, released below, ends the notices.
        let coordinator = try makeCoordinator(
            fixture: fixture, keys: keys, transport: transport, noticeNanoseconds: 600_000_000_000,
            backgroundTime: backgroundTime.request
        )
        _ = try await coordinator.sessionsToReconnect()

        // Run apart, so a call that waited for its notice again fails here instead of hanging the test.
        let returned = TonConnectPostCounter()
        let calls = Task { @MainActor in
            defer { returned.increment() }
            try await coordinator.reconnect([offered])
            try await coordinator.disconnect(swiped)
        }
        for _ in 0 ..< 500 where returned.value == 0 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(returned.value, 1, "Both calls returned while the bridge still holds the notices")
        if returned.value == 0 {
            transport.release()
        }
        try await calls.value

        XCTAssertTrue(try fixture.snapshot().isEmpty, "Both sessions are gone when the calls return")
        XCTAssertTrue(keys.items.isEmpty)
        XCTAssertEqual(coordinator.disconnectNoticesInFlight, 2, "Neither call waited for its notice")
        XCTAssertEqual(backgroundTime.requested, 2, "Each notice holds background time in case the app leaves the screen")
        XCTAssertEqual(backgroundTime.ended, 0)
        for _ in 0 ..< 500 where transport.sends < 2 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(transport.sends, 2, "Both notices are on their way")
        XCTAssertEqual(coordinator.disconnectNoticesInFlight, 2)

        transport.release()
        await coordinator.waitForDisconnectNotices()
        XCTAssertEqual(coordinator.disconnectNoticesInFlight, 0, "Delivered notices end by themselves")
        XCTAssertEqual(backgroundTime.ended, 2, "Each gives its background time back, once")
    }

    /// Review minor (2026-11-24): if iOS ends the background time first, the notice is given up then.
    @MainActor
    func testANoticeWhoseBackgroundTimeRunsOutIsGivenUp() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let transport = TonConnectHangingTransport()
        let session = try tonConnectTestSession(id: "swiped", walletId: "legacy-wallet", host: "a.example.org")
        try fixture.insert(session)
        let backgroundTime = TonConnectBackgroundTimeRecorder()
        let logger = TonConnectRecordingLogger()
        let coordinator = try makeCoordinator(
            fixture: fixture, keys: keys, transport: transport, noticeNanoseconds: 600_000_000_000, logger: logger,
            backgroundTime: backgroundTime.request
        )
        _ = try await coordinator.selectedSessions()
        try await coordinator.disconnect(session)
        for _ in 0 ..< 500 where transport.maximumInFlight < 1 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(transport.maximumInFlight, 1, "The notice is on its way")
        XCTAssertEqual(coordinator.disconnectNoticesInFlight, 1)

        backgroundTime.expireAll()
        // Polled, not awaited: a notice that ignored the expiry would otherwise hold the test for its deadline.
        for _ in 0 ..< 500 where coordinator.disconnectNoticesInFlight > 0 {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(coordinator.disconnectNoticesInFlight, 0, "The notice ended with the background time")
        XCTAssertEqual(transport.cancelledSends, 1, "The send is cancelled")
        XCTAssertEqual(backgroundTime.ended, 1, "The background time is given back once")
        XCTAssertEqual(logger.warnings, ["A TON Connect application was not told about a disconnect; the session is removed"])
        XCTAssertTrue(try fixture.snapshot().isEmpty, "The disconnect itself is not undone")
    }

    @MainActor
    func testTheBackgroundTimeEndsOnceWhoeverEndsItFirst() {
        var expiries = 0
        let end = LegacyTonConnectBackgroundTime.request { expiries += 1 }
        end()
        end()
        XCTAssertEqual(expiries, 0, "Ending it is not running out of time")
    }

    @MainActor
    func testARecordedDisconnectThatCannotFinishStillTellsTheApplicationAndIsFinishedLater() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let transport = TonConnectFakeTransport()
        let offered = try tonConnectTestSession(id: "offered", walletId: "legacy-wallet", host: "a.example.org")
        let swiped = try tonConnectTestSession(id: "swiped", walletId: "legacy-wallet", host: "b.example.org")
        try fixture.insert(offered)
        try fixture.insert(swiped)
        let coordinator = try makeCoordinator(fixture: fixture, keys: keys, transport: transport)
        let waiting = try await coordinator.sessionsToReconnect()
        XCTAssertEqual(Set(waiting.map(\.identifier)), [offered.identifier, swiped.identifier])

        keys.failDeletes = errSecInteractionNotAllowed
        do {
            try await coordinator.reconnect([offered])
            XCTFail("An unfinished disconnect is reported")
        } catch {
            XCTAssertTrue(error is LegacyTonConnectUnfinishedRemoval)
        }
        do {
            try await coordinator.disconnect(swiped)
            XCTFail("An unfinished disconnect is reported")
        } catch {
            XCTAssertTrue(error is LegacyTonConnectUnfinishedRemoval)
        }
        await coordinator.waitForDisconnectNotices()
        XCTAssertEqual(transport.sent.map { $0.1.identifier }.sorted(), [offered.identifier, swiped.identifier],
                       "Both applications are told: the sessions are retired for good")
        XCTAssertEqual(keys.retired.count, 2)
        let listedMeanwhile = try await coordinator.selectedSessions()
        XCTAssertTrue(listedMeanwhile.isEmpty, "Neither session is usable while its removal waits")

        keys.failDeletes = nil
        _ = try await coordinator.selectedSessions()
        XCTAssertTrue(try fixture.snapshot().isEmpty, "The next read finished both removals")
        XCTAssertTrue(keys.items.isEmpty)
    }

    @MainActor
    func testADisconnectThatCannotStartKeepsTheSessionWaitingAndIsReportedAfterTheOthers() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let keys = TonConnectFakeSessionKeys()
        let transport = TonConnectFakeTransport()
        let first = try tonConnectTestSession(id: "first", walletId: "legacy-wallet", host: "a.example.org")
        try fixture.insert(first)
        let coordinator = try makeCoordinator(fixture: fixture, keys: keys, transport: transport)
        let offered = try await coordinator.sessionsToReconnect()
        XCTAssertEqual(offered, [first])
        let before = try fixture.snapshot()

        keys.failLoads = errSecInteractionNotAllowed
        do {
            try await coordinator.reconnect(offered)
            XCTFail("A disconnect that could not happen is reported")
        } catch {}
        XCTAssertEqual(try fixture.snapshot(), before, "The session and its mark stay as they were")
        XCTAssertEqual(keys.items[reference(first).account], first.privateKey)

        keys.failLoads = nil
        let offeredAgain = try await coordinator.sessionsToReconnect()
        XCTAssertEqual(offeredAgain, [first], "Not answered by a failure: offered again")
    }
}

final class LegacyTonConnectReconnectOfferViewTests: XCTestCase {
    /// The languages the app bundle ships (`pt.lproj` is kept in the tree but not in the target).
    private static let locales = ["en", "id", "ja", "pt-PT", "ru", "tr", "vi", "zh-Hans"]

    func testTheNoticeIsShortAndTranslatedInEveryShippedLanguage() throws {
        let english = R.string.localizable.tonconnectReconnectMessage(preferredLanguages: ["en"])
        for locale in Self.locales {
            let languages = [locale]
            let title = R.string.localizable.tonconnectReconnectTitle(preferredLanguages: languages)
            let message = R.string.localizable.tonconnectReconnectMessage(preferredLanguages: languages)
            let action = R.string.localizable.tonconnectReconnectAction(preferredLanguages: languages)
            let keep = R.string.localizable.tonconnectReconnectKeep(preferredLanguages: languages)
            for text in [title, message, action, keep] {
                XCTAssertFalse(text.isEmpty, locale)
                XCTAssertFalse(text.hasPrefix("tonconnect."), "\(locale) has its own text")
            }
            XCTAssertLessThanOrEqual(message.count, 200, "\(locale): one warning, one action, kept short")
            XCTAssertLessThanOrEqual(title.count, 40, locale)
            if locale != "en" {
                XCTAssertNotEqual(message, english, "\(locale) is translated")
            }
        }
    }

    func testTheOfferNamesEachHostOnceAndAtMostFive() throws {
        let sessions = try (0 ..< 8).map { index in
            try tonConnectTestSession(id: "s\(index)", walletId: "legacy-wallet", host: "app\(index % 7).example.org")
        }
        var answers: [String] = []
        let alert = LegacyTonConnectReconnectOffer.alert(
            for: sessions, languages: ["en"], disconnect: { answers.append("disconnect") }, keep: { answers.append("keep") }
        )
        let message = try XCTUnwrap(alert.message)
        let body = R.string.localizable.tonconnectReconnectMessage(preferredLanguages: ["en"])
        XCTAssertEqual(message, body + "\n\n" + (0 ..< 5).map { "app\($0).example.org" }.joined(separator: "\n") + "\n…")
        XCTAssertEqual(alert.title, R.string.localizable.tonconnectReconnectTitle(preferredLanguages: ["en"]))
        XCTAssertEqual(alert.actions.map(\.style), [.cancel, .destructive])
        XCTAssertEqual(alert.actions.map(\.title), ["Keep connected", "Disconnect"])
        XCTAssertNil(alert.preferredAction, "Return on a hardware keyboard never picks Disconnect")
        CovEAlert.tap(alert.actions[0])
        CovEAlert.tap(alert.actions[1])
        XCTAssertEqual(answers, ["keep", "disconnect"])

        let one = LegacyTonConnectReconnectOffer.alert(for: Array(sessions.prefix(2)) + [sessions[0]], languages: ["ja"], disconnect: {}, keep: {})
        XCTAssertEqual(one.message, R.string.localizable.tonconnectReconnectMessage(preferredLanguages: ["ja"]) + "\n\napp0.example.org\napp1.example.org")
    }

    @MainActor
    private func host(_ controller: UIViewController) throws -> (UIWindow, () -> Void) {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive }))
        let previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        return (window, {
            window.rootViewController?.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            previousKeyWindow?.makeKey()
        })
    }

    @MainActor
    private func waitUntil(_ timeout: TimeInterval = 10, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// Answers the offer as a tap would: the alert closes first, then its action runs.
    @MainActor
    private func answer(_ alert: UIAlertController, on controller: UIViewController, action index: Int) async throws {
        try await waitUntil { alert.viewIfLoaded?.window != nil && !alert.isBeingPresented && alert.transitionCoordinator == nil }
        controller.dismiss(animated: false)
        try await waitUntil { controller.presentedViewController == nil }
        XCTAssertNil(controller.presentedViewController)
        CovEAlert.tap(alert.actions[index])
    }

    @MainActor
    private func makeCoordinator(
        _ store: TonConnectFakeSessionStore,
        transport: LegacyTonConnectBridgeTransporting,
        noticeNanoseconds: UInt64 = 5_000_000_000
    ) throws -> LegacyTonConnectCoordinator {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectTestWallet(keys)
        return LegacyTonConnectCoordinator(
            store: store, transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, networkSelection: { "-239" }, walletLoader: { _ in wallet }, isEnabled: { true },
            disconnectNoticeNanoseconds: noticeNanoseconds, logger: TonConnectRecordingLogger()
        )
    }

    @MainActor
    private func cellText(_ controller: UITableViewController, row: Int = 0) -> String? {
        controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: row, section: 0)).textLabel?.text
    }

    @MainActor
    func testTheListOffersOnceAndKeepingTheSessionsEndsIt() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let browser = try tonConnectTestSession(id: "browser", walletId: "legacy-wallet", host: "b.example.org", type: "js")
        let store = TonConnectFakeSessionStore(values: [bridge, browser])
        store.waiting = [bridge, browser]
        let transport = TonConnectFakeTransport()
        let controller = LegacyTonConnectSessionsViewController(coordinator: try makeCoordinator(store, transport: transport))
        let (_, close) = try host(controller)
        defer { close() }

        try await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        let languages = LegacyTonConnectProtocol.languages
        XCTAssertEqual(alert.title, R.string.localizable.tonconnectReconnectTitle(preferredLanguages: languages))
        XCTAssertEqual(alert.message, R.string.localizable.tonconnectReconnectMessage(preferredLanguages: languages) + "\n\na.example.org",
                       "Only the bridge session is named")

        try await answer(alert, on: controller, action: 0)
        try await waitUntil { store.waiting == [browser] }
        XCTAssertEqual(store.waiting, [browser], "The kept session is not offered again")
        XCTAssertEqual(store.values, [bridge, browser], "Keeping disconnects nothing")
        XCTAssertTrue(transport.sent.isEmpty)

        controller.refreshControl?.sendActions(for: .valueChanged)
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertNil(controller.presentedViewController, "Answered once, never asked again")
    }

    @MainActor
    func testDisconnectingFromTheOfferRemovesTheSessionsAndRefreshesTheList() async throws {
        let first = try tonConnectTestSession(id: "first", walletId: "legacy-wallet", host: "a.example.org")
        let second = try tonConnectTestSession(id: "second", walletId: "legacy-wallet", host: "b.example.org")
        let kept = try tonConnectTestSession(id: "kept", walletId: "legacy-wallet", host: "c.example.org")
        let store = TonConnectFakeSessionStore(values: [first, second, kept])
        store.waiting = [first, second]
        let transport = TonConnectFakeTransport()
        let coordinator = try makeCoordinator(store, transport: transport)
        let controller = LegacyTonConnectSessionsViewController(coordinator: coordinator)
        let (_, close) = try host(controller)
        defer { close() }

        try await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertTrue(alert.message?.hasSuffix("\n\na.example.org\nb.example.org") == true)
        try await answer(alert, on: controller, action: 1)

        try await waitUntil { store.values == [kept] && controller.tableView.numberOfRows(inSection: 0) == 1 }
        XCTAssertEqual(store.values, [kept], "Only the offered sessions are disconnected")
        await coordinator.waitForDisconnectNotices()
        XCTAssertEqual(transport.sent.map { $0.3 }, ["disconnect", "disconnect"])
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 1)
        XCTAssertNil(controller.presentedViewController)
    }

    @MainActor
    func testOpeningTheListAsASheetOffersWithoutARefresh() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        store.waiting = [bridge]
        let coordinator = try makeCoordinator(store, transport: TonConnectFakeTransport())
        let root = UIViewController()
        let (_, close) = try host(root)
        defer { close() }
        try await waitUntil { root.viewIfLoaded?.window != nil }

        coordinator.presentSessions(from: root)

        var list: LegacyTonConnectSessionsViewController? {
            (root.navigationController?.presentedViewController as? UINavigationController)?.topViewController
                as? LegacyTonConnectSessionsViewController
        }
        try await waitUntil { list?.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(list?.presentedViewController as? UIAlertController)
        XCTAssertTrue(alert.message?.hasSuffix("\n\na.example.org") == true)
        try await waitUntil { alert.viewIfLoaded?.window != nil && !alert.isBeingPresented }
    }

    @MainActor
    func testAListThatCouldNotLoadBehindTheLockLoadsAndOffersAfterTheUnlock() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        store.waiting = [bridge]
        store.failReads = true
        let lockState = ApplicationLockState.shared
        lockState.markLockPending()
        defer { lockState.cancelPendingLock() }
        let controller = LegacyTonConnectSessionsViewController(coordinator: try makeCoordinator(store, transport: TonConnectFakeTransport()))
        let (_, close) = try host(controller)
        defer { close() }
        try await waitUntil(2) { controller.presentedViewController != nil }
        XCTAssertNil(controller.presentedViewController, "No error is shown for a read the lock held back")

        store.failReads = false
        lockState.cancelPendingLock()
        try await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.tonconnectReconnectTitle(preferredLanguages: LegacyTonConnectProtocol.languages),
                       "The offer, not an error, after the unlock and without a refresh")
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 1)
    }

    @MainActor
    func testAnUnlockDuringAFailingFirstLoadStillLoadsAndOffers() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        store.waiting = [bridge]
        store.holdNextReadAndFailIt()
        let lockState = ApplicationLockState.shared
        lockState.markLockPending()
        defer { lockState.cancelPendingLock() }
        let controller = LegacyTonConnectSessionsViewController(coordinator: try makeCoordinator(store, transport: TonConnectFakeTransport()))
        let (_, close) = try host(controller)
        defer { close() }
        try await waitUntil { store.isHoldingRead }
        XCTAssertTrue(store.isHoldingRead, "The first load is still running")

        lockState.cancelPendingLock()
        try await Task.sleep(nanoseconds: 200_000_000)
        store.releaseRead()

        try await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.tonconnectReconnectTitle(preferredLanguages: LegacyTonConnectProtocol.languages),
                       "The load asked for by the unlock runs and offers; the superseded failure is not shown")
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 1)
    }

    /// Codex review (round 4): the failed read's completion is queued on the main actor before the unlock is posted.
    @MainActor
    func testAFailedLoadQueuedBeforeTheUnlockIsNotShownAndTheListLoadsAndOffers() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        store.waiting = [bridge]
        store.holdNextReadAndFailIt()
        let lockState = ApplicationLockState.shared
        lockState.markLockPending()
        defer { lockState.cancelPendingLock() }
        let controller = LegacyTonConnectSessionsViewController(coordinator: try makeCoordinator(store, transport: TonConnectFakeTransport()))
        let (_, close) = try host(controller)
        defer { close() }
        try await waitUntil { store.isHoldingRead }
        XCTAssertTrue(store.isHoldingRead)

        // The failed read's completion is queued on the main actor (held here, without suspending) before the
        // unlock is posted: the unlock must still win over the failure.
        store.releaseRead()
        XCTAssertEqual(store.heldReadFailed.wait(timeout: .now() + 10), .success)
        Thread.sleep(forTimeInterval: 0.5)
        lockState.cancelPendingLock()

        try await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.tonconnectReconnectTitle(preferredLanguages: LegacyTonConnectProtocol.languages),
                       "The offer, not the error of a read the lock held back")
        XCTAssertEqual(controller.tableView.numberOfRows(inSection: 0), 1)
    }

    @MainActor
    func testASwipeWhoseRemovalIsUnfinishedShowsTheErrorAndDropsTheRow() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        store.removalError = LegacyTonConnectUnfinishedRemoval(underlying: LegacyTonConnectSessionKeyError.keychainUnavailable(errSecInteractionNotAllowed))
        let transport = TonConnectFakeTransport()
        let coordinator = try makeCoordinator(store, transport: transport)
        let controller = LegacyTonConnectSessionsViewController(coordinator: coordinator)
        let (_, close) = try host(controller)
        defer { close() }
        try await waitUntil { controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0)).textLabel?.text == bridge.name }

        let removalError = try XCTUnwrap(store.removalError)
        let action = try XCTUnwrap(controller.tableView(controller.tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))?.actions.first)
        var completed: [Bool] = []
        action.handler(action, UIView()) { completed.append($0) }
        try await waitUntil { !completed.isEmpty && controller.presentedViewController is UIAlertController }

        XCTAssertEqual(completed, [false])
        await coordinator.waitForDisconnectNotices()
        XCTAssertEqual(transport.sent.map { $0.3 }, ["disconnect"], "The application is told")
        try await waitUntil {
            controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0)).textLabel?.text == "No connected applications"
        }
        XCTAssertEqual(controller.tableView(controller.tableView, cellForRowAt: IndexPath(row: 0, section: 0)).textLabel?.text,
                       "No connected applications", "The retired session leaves the list")
        let shown = try XCTUnwrap(controller.presentedViewController as? UIAlertController, "The cleanup error is shown")
        XCTAssertEqual(shown.message, removalError.localizedDescription)
    }

    @MainActor
    func testNothingIsOfferedBehindTheLockOrWhenNothingWaits() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        let transport = TonConnectFakeTransport()
        let quiet = LegacyTonConnectSessionsViewController(coordinator: try makeCoordinator(store, transport: transport))
        let (_, closeQuiet) = try host(quiet)
        try await waitUntil(2) { quiet.tableView.numberOfRows(inSection: 0) == 1 && quiet.presentedViewController != nil }
        XCTAssertNil(quiet.presentedViewController, "A session made by this version is never offered")
        closeQuiet()

        store.waiting = [bridge]
        let lockState = ApplicationLockState.shared
        lockState.markLockPending()
        defer { lockState.cancelPendingLock() }
        let locked = LegacyTonConnectSessionsViewController(coordinator: try makeCoordinator(store, transport: transport))
        let (_, closeLocked) = try host(locked)
        defer { closeLocked() }
        try await waitUntil(2) { locked.presentedViewController != nil }
        XCTAssertNil(locked.presentedViewController, "Nothing is asked behind the lock")
        XCTAssertEqual(store.waiting, [bridge], "Not asked, so still waiting")

        lockState.cancelPendingLock()
        try await waitUntil { locked.presentedViewController is UIAlertController }
        XCTAssertTrue(locked.presentedViewController is UIAlertController, "Asked once the wallet is unlocked, without a refresh")
    }

    /// Review minor (2026-11-24): the swipe closes and the row goes as soon as the session is removed here, while
    /// the application's bridge has not taken the notice yet.
    @MainActor
    func testASwipeFinishesOnceTheSessionIsRemovedAndTheApplicationIsToldLater() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        let transport = TonConnectStuckTransport()
        defer { transport.release() }
        // A deadline far beyond the test: only the bridge, released below, ends the notice.
        let coordinator = try makeCoordinator(store, transport: transport, noticeNanoseconds: 600_000_000_000)
        let controller = LegacyTonConnectSessionsViewController(coordinator: coordinator)
        let (_, close) = try host(controller)
        defer { close() }
        try await waitUntil { cellText(controller) == bridge.name }

        let action = try XCTUnwrap(controller.tableView(controller.tableView, trailingSwipeActionsConfigurationForRowAt: IndexPath(row: 0, section: 0))?.actions.first)
        var completed: [Bool] = []
        action.handler(action, UIView()) { completed.append($0) }
        try await waitUntil { !completed.isEmpty && cellText(controller) == "No connected applications" }

        XCTAssertEqual(completed, [true], "The swipe closes as soon as the session is removed")
        XCTAssertEqual(cellText(controller), "No connected applications")
        XCTAssertEqual(store.values, [])
        XCTAssertEqual(coordinator.disconnectNoticesInFlight, 1, "The application has not been told yet")
        XCTAssertNil(controller.presentedViewController)

        transport.release()
        await coordinator.waitForDisconnectNotices()
        XCTAssertEqual(transport.sends, 1, "The application is told in the background")
        XCTAssertNil(controller.presentedViewController, "A notice is never reported on screen")
    }

    /// Review minor (2026-11-24): the offer's "Disconnect" updates the list once the sessions are removed here, while
    /// their applications have not been told yet.
    @MainActor
    func testDisconnectingFromTheOfferUpdatesTheListBeforeTheApplicationsAreTold() async throws {
        let first = try tonConnectTestSession(id: "first", walletId: "legacy-wallet", host: "a.example.org")
        let second = try tonConnectTestSession(id: "second", walletId: "legacy-wallet", host: "b.example.org")
        let kept = try tonConnectTestSession(id: "kept", walletId: "legacy-wallet", host: "c.example.org")
        let store = TonConnectFakeSessionStore(values: [first, second, kept])
        store.waiting = [first, second]
        let transport = TonConnectStuckTransport()
        defer { transport.release() }
        let coordinator = try makeCoordinator(store, transport: transport, noticeNanoseconds: 600_000_000_000)
        let controller = LegacyTonConnectSessionsViewController(coordinator: coordinator)
        let (_, close) = try host(controller)
        defer { close() }

        try await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        try await answer(alert, on: controller, action: 1)

        try await waitUntil { controller.tableView.numberOfRows(inSection: 0) == 1 && cellText(controller) == kept.name }
        XCTAssertEqual(store.values, [kept])
        XCTAssertEqual(cellText(controller), kept.name, "The removed sessions leave the list at once")
        XCTAssertEqual(coordinator.disconnectNoticesInFlight, 1, "Their applications have not been told yet")
        XCTAssertNil(controller.presentedViewController)

        transport.release()
        await coordinator.waitForDisconnectNotices()
        XCTAssertEqual(transport.sends, 2, "Both applications are told in the background")
    }

    /// Review minor (2026-11-24): a read that failed on a locked device, or with the app not in front, is not shown;
    /// the list loads and offers once protected data is available or the app is active again.
    @MainActor
    func testALoadThatFailedOnALockedDeviceIsNotShownAndLoadsOnceTheDeviceUnlocks() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let offerTitle = R.string.localizable.tonconnectReconnectTitle(preferredLanguages: LegacyTonConnectProtocol.languages)

        // On an unlocked device with the app in front, the same failure is shown.
        let shownStore = TonConnectFakeSessionStore(values: [bridge])
        shownStore.failReads = true
        let shownCenter = NotificationCenter()
        let shown = LegacyTonConnectSessionsViewController(
            coordinator: try makeCoordinator(shownStore, transport: TonConnectFakeTransport()),
            notificationCenter: shownCenter, isDeviceReadable: { true }
        )
        let (_, closeShown) = try host(shown)
        try await waitUntil { shown.presentedViewController is UIAlertController }
        XCTAssertEqual((shown.presentedViewController as? UIAlertController)?.title, "TonConnect", "An ordinary failure is shown")
        // Shown once: coming back to the app does not show it again each time.
        shown.dismiss(animated: false)
        try await waitUntil { shown.presentedViewController == nil }
        for trigger in [UIApplication.didBecomeActiveNotification, UIApplication.protectedDataDidBecomeAvailableNotification] {
            shownCenter.post(name: trigger, object: nil)
        }
        try await waitUntil(1.5) { shown.presentedViewController != nil }
        XCTAssertNil(shown.presentedViewController, "A failure already shown is not shown again on each activation")
        closeShown()

        for trigger in [UIApplication.protectedDataDidBecomeAvailableNotification, UIApplication.didBecomeActiveNotification] {
            let store = TonConnectFakeSessionStore(values: [bridge])
            store.waiting = [bridge]
            store.failReads = true
            let center = NotificationCenter()
            var readable = false
            let controller = LegacyTonConnectSessionsViewController(
                coordinator: try makeCoordinator(store, transport: TonConnectFakeTransport()),
                notificationCenter: center, isDeviceReadable: { readable }
            )
            let (_, close) = try host(controller)
            defer { close() }
            try await waitUntil(2) { controller.presentedViewController != nil }
            XCTAssertNil(controller.presentedViewController, "\(trigger.rawValue): no error for a read the locked device held back")
            XCTAssertEqual(cellText(controller), "No connected applications", trigger.rawValue)

            store.failReads = false
            readable = true
            center.post(name: trigger, object: nil)
            try await waitUntil { controller.presentedViewController is UIAlertController }
            let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController, trigger.rawValue)
            XCTAssertEqual(alert.title, offerTitle, "\(trigger.rawValue): the offer, not an error, without a refresh")
            XCTAssertEqual(cellText(controller), bridge.name, trigger.rawValue)
        }
    }

    /// Review follow-up (2026-11-24): a list that loaded while the device is locked or the app is not in front offers
    /// nothing until the device is unlocked and the app is in front.
    @MainActor
    func testNothingIsOfferedOnALockedDeviceOrInAnInactiveApp() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let offerTitle = R.string.localizable.tonconnectReconnectTitle(preferredLanguages: LegacyTonConnectProtocol.languages)
        for trigger in [UIApplication.protectedDataDidBecomeAvailableNotification, UIApplication.didBecomeActiveNotification] {
            let store = TonConnectFakeSessionStore(values: [bridge])
            store.waiting = [bridge]
            let center = NotificationCenter()
            var readable = false
            let controller = LegacyTonConnectSessionsViewController(
                coordinator: try makeCoordinator(store, transport: TonConnectFakeTransport()),
                notificationCenter: center, isDeviceReadable: { readable }
            )
            let (_, close) = try host(controller)
            defer { close() }
            try await waitUntil { cellText(controller) == bridge.name }
            try await waitUntil(2) { controller.presentedViewController != nil }
            XCTAssertEqual(cellText(controller), bridge.name, "\(trigger.rawValue): the list loaded")
            XCTAssertNil(controller.presentedViewController, "\(trigger.rawValue): nothing is offered on a locked device")

            readable = true
            center.post(name: trigger, object: nil)
            try await waitUntil { controller.presentedViewController is UIAlertController }
            let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController, trigger.rawValue)
            XCTAssertEqual(alert.title, offerTitle, trigger.rawValue)
            XCTAssertEqual(store.waiting, [bridge], "Offered, not yet answered")
        }
    }

    /// Review minor (2026-11-24): the lock can end with nothing posted (its PIN screen went away). A load that started
    /// behind it and failed is not shown; the list loads again at once and offers.
    @MainActor
    func testALoadStartedBehindALockThatEndedWithoutANoticeLoadsAndOffers() async throws {
        let bridge = try tonConnectTestSession(id: "bridge", walletId: "legacy-wallet", host: "a.example.org")
        let store = TonConnectFakeSessionStore(values: [bridge])
        store.waiting = [bridge]
        store.holdNextReadAndFailIt()
        let lockState = ApplicationLockState.shared
        var pinScreen: UIViewController? = UIViewController()
        autoreleasepool { lockState.lock(with: pinScreen!) }
        defer {
            lockState.unlock()
            // The app's other observers heard "locked": they hear that it ended too.
            NotificationCenter.default.post(name: ApplicationLockState.didChangeNotification, object: lockState)
        }
        XCTAssertTrue(lockState.isLocked)
        let controller = LegacyTonConnectSessionsViewController(coordinator: try makeCoordinator(store, transport: TonConnectFakeTransport()))
        let (_, close) = try host(controller)
        defer { close() }
        try await waitUntil { store.isHoldingRead }
        XCTAssertTrue(store.isHoldingRead, "The first load started behind the lock and is still running")

        let posts = TonConnectPostCounter()
        let observer = NotificationCenter.default.addObserver(
            forName: ApplicationLockState.didChangeNotification, object: lockState, queue: nil
        ) { _ in posts.increment() }
        defer { NotificationCenter.default.removeObserver(observer) }
        autoreleasepool { pinScreen = nil }
        XCTAssertFalse(lockState.isLocked, "The PIN screen is gone, so the lock ended")
        store.releaseRead()

        try await waitUntil { controller.presentedViewController is UIAlertController }
        let alert = try XCTUnwrap(controller.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, R.string.localizable.tonconnectReconnectTitle(preferredLanguages: LegacyTonConnectProtocol.languages),
                       "The offer, not the error of a read the lock held back")
        XCTAssertEqual(cellText(controller), bridge.name)
        XCTAssertEqual(posts.value, 0, "Nothing announced the end of the lock")
    }
}

// MARK: - A decided connection's reply that the bridge did not take (Codex rounds 6 and 8, 2026-11-23)

/// Opens once; every waiter before and after passes.
private final class TonConnectSendGate {
    private let lock = NSLock()
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    var waiting: Int {
        lock.lock()
        defer { lock.unlock() }
        return waiters.count
    }

    func wait() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            if isOpen {
                lock.unlock()
                continuation.resume()
            } else {
                waiters.append(continuation)
                lock.unlock()
            }
        }
    }

    func open() {
        lock.lock()
        isOpen = true
        let released = waiters
        waiters = []
        lock.unlock()
        released.forEach { $0.resume() }
    }
}

/// Parks each retry of a kept reply until the test lets it go, in place of the retry delays. Pass `pass` as the
/// coordinator's `replyRetryWait`: it runs on the main actor like the retry, so once `resumed` counts a released
/// retry, that retry has also made its synchronous decision (a cancelled one has ended).
private final class TonConnectRetryGate {
    private let lock = NSLock()
    private var parked: [CheckedContinuation<Void, Never>] = []
    private var count = 0
    private var resumedCount = 0

    var entered: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    var resumed: Int {
        lock.lock()
        defer { lock.unlock() }
        return resumedCount
    }

    var pass: @MainActor (UInt64) async -> Void {
        { [self] delay in
            await wait(delay)
            markResumed()
        }
    }

    private func markResumed() {
        lock.lock()
        resumedCount += 1
        lock.unlock()
    }

    func wait(_: UInt64) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            lock.lock()
            count += 1
            parked.append(continuation)
            lock.unlock()
        }
    }

    func releaseAll() {
        lock.lock()
        let released = parked
        parked = []
        lock.unlock()
        released.forEach { $0.resume() }
    }
}

private final class TonConnectEventLog {
    private let lock = NSLock()
    private var stored: [String] = []

    var events: [String] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    func append(_ event: String) {
        lock.lock()
        stored.append(event)
        lock.unlock()
    }
}

private final class TonConnectLoggingSessionStore: LegacyTonConnectSessionStoring {
    private let log: TonConnectEventLog
    private(set) var values: [LegacyTonConnectSession]
    var failRemovals = 0

    init(values: [LegacyTonConnectSession], log: TonConnectEventLog) {
        self.values = values
        self.log = log
    }

    func sessions() async throws -> [LegacyTonConnectSession] { values }
    func sessionsToReconnect() async throws -> [LegacyTonConnectSession] { [] }
    func finishReconnectOffer(for _: [LegacyTonConnectSession]) async throws {}
    func save(_ session: LegacyTonConnectSession) async throws { if !values.contains(session) { values.append(session) } }

    func remove(_ session: LegacyTonConnectSession) async throws {
        guard failRemovals == 0 else {
            failRemovals -= 1
            log.append("remove failed")
            throw KeystoreError.unexpectedFail
        }
        log.append("remove")
        values.removeAll { $0 == session }
    }

    func bridgeURL(network _: String) async throws -> URL { URL(string: "https://bridge.example.org/bridge")! }
}

private final class TonConnectDisconnectRecordingHandler: LegacyTonConnectRequestHandling {
    private let log: TonConnectEventLog
    init(log: TonConnectEventLog) { self.log = log }

    func process(
        session _: LegacyTonConnectSession, network _: String, request _: LegacyTonConnectRPCRequest
    ) async throws -> LegacyTonConnectRPCOutcome {
        throw LegacyTonConnectError.unavailableWallet
    }

    func acknowledge(
        session _: LegacyTonConnectSession, network _: String, request _: LegacyTonConnectRPCRequest, messageHashHex _: String
    ) async throws {}

    func sessionWillDisconnect(_: LegacyTonConnectSession) async { log.append("willDisconnect") }
}

/// A flag the session store may flip off the main thread while the coordinator reads it on main.
private final class TonConnectLockedFlag {
    private let lock = NSLock()
    private var stored: Bool
    init(_ value: Bool) { stored = value }
    var value: Bool {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); stored = newValue; lock.unlock() }
    }
}

/// Refuses the first `failures` sends, then takes them; sends from `gatedFromAttempt` on wait for `gate` first.
/// `send` runs on the main actor like the retry, so a try is counted in the same job as the decision to send it.
/// Counters are read on main while the listener runs elsewhere.
private final class TonConnectFlakyReplyTransport: LegacyTonConnectBridgeTransporting {
    let gate = TonConnectSendGate()
    private let lock = NSLock()
    private var failuresLeft: Int
    private var gatedFrom = Int.max
    private var attemptCount = 0
    private var listenCount = 0
    private var manifestCount = 0
    private var tried: [(data: Data, topic: String)] = []
    private var delivered: [(data: Data, session: LegacyTonConnectSession, bridge: URL, topic: String)] = []

    init(failures: Int) { failuresLeft = failures }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var gatedFromAttempt: Int {
        get { locked { gatedFrom } }
        set { locked { gatedFrom = newValue } }
    }

    var attempts: Int { locked { attemptCount } }
    var listens: Int { locked { listenCount } }
    var manifestCalls: Int { locked { manifestCount } }
    /// Every payload handed to `send`, refused or not, in order.
    var triedPayloads: [Data] { locked { tried.map(\.data) } }
    /// The topic of every send, refused or not, in order: `connect` replies and `disconnect` notices.
    var triedTopics: [String] { locked { tried.map(\.topic) } }
    var sent: [(data: Data, session: LegacyTonConnectSession, bridge: URL, topic: String)] { locked { delivered } }

    func manifest(at url: URL) async throws -> LegacyTonConnectManifest {
        locked { manifestCount += 1 }
        return .init(url: url, name: "Fixture", iconUrl: nil)
    }

    @MainActor
    func send(_ data: Data, session: LegacyTonConnectSession, bridge: URL, topic: String) async throws {
        let gated: Bool = locked {
            attemptCount += 1
            tried.append((data, topic))
            return attemptCount >= gatedFrom
        }
        if gated {
            await gate.wait()
        }
        let refused: Bool = locked {
            guard failuresLeft > 0 else {
                delivered.append((data, session, bridge, topic))
                return false
            }
            failuresLeft -= 1
            return true
        }
        if refused { throw URLError(.networkConnectionLost) }
    }

    func listen(
        session _: LegacyTonConnectSession, context _: LegacyTonConnectSessionContext,
        receive _: @escaping (Data, String?) async throws -> Void
    ) async throws {
        locked { listenCount += 1 }
        throw URLError(.notConnectedToInternet)
    }
}

/// Runs a hook once, from inside the next `sessions()` read after it was armed, before that read returns the list
/// it read before the hook ran. On the main actor like the retry that reads it: once `hookFired` is set, that retry
/// has also made its decision.
@MainActor
private final class TonConnectHookedSessionStore: LegacyTonConnectSessionStoring {
    private let lock = NSLock()
    private var stored: [LegacyTonConnectSession] = []
    private var hook: (() async -> Void)?
    private var fired = false
    private var readCount = 0

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var values: [LegacyTonConnectSession] { locked { stored } }
    var hookFired: Bool { locked { fired } }
    var reads: Int { locked { readCount } }

    func arm(_ hook: @escaping () async -> Void) { locked { self.hook = hook } }

    func sessions() async throws -> [LegacyTonConnectSession] {
        let (snapshot, pending): ([LegacyTonConnectSession], (() async -> Void)?) = locked {
            readCount += 1
            let pending = hook
            hook = nil
            return (stored, pending)
        }
        if let pending {
            await pending()
            locked { fired = true }
        }
        return snapshot
    }

    func sessionsToReconnect() async throws -> [LegacyTonConnectSession] { [] }
    func finishReconnectOffer(for _: [LegacyTonConnectSession]) async throws {}

    func save(_ session: LegacyTonConnectSession) async throws {
        locked { if !stored.contains(session) { stored.append(session) } }
    }

    func remove(_ session: LegacyTonConnectSession) async throws { locked { stored.removeAll { $0 == session } } }
    func bridgeURL(network _: String) async throws -> URL { URL(string: "https://bridge.example.org/bridge")! }
}

@MainActor
private func tonConnectWaitUntil(
    _ message: String, timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line,
    _ condition: () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() {
        guard Date() < deadline else {
            XCTFail(message, file: file, line: line)
            return
        }
        try await Task.sleep(nanoseconds: 10_000_000)
    }
}

private func tonConnectNativeWallet(_ keys: TonConnectFixtureKeychain) throws -> MetaAccountModel {
    let pair = try TonSwift.Mnemonic.mnemonicToPrivateKey(mnemonicArray: tonConnectNativePhrase.components(separatedBy: " "))
    let account = try LegacyTonAccount(serializedAddress: JSONEncoder().encode(WalletV4R2(publicKey: pair.publicKey.data).address()),
                                       publicKey: pair.publicKey.data, contractVersion: "v4R2")
    keys.values[KeystoreTagV2.tonSecretKeyTagForMetaId("legacy-wallet")] = pair.privateKey.data
    return MetaAccountModel(metaId: "legacy-wallet", name: "Original native TON", substrateAccountId: nil,
        substrateCryptoType: 0, substratePublicKey: nil, ethereumAddress: nil, ethereumPublicKey: nil,
        chainAccounts: [], assetKeysOrder: nil, canExportEthereumMnemonic: false, unusedChainIds: nil,
        selectedCurrency: .defaultCurrency(), networkManagmentFilter: nil, assetsVisibility: [],
        hasBackup: true, favouriteChainIds: [], legacyTonAccount: account)
}

private func tonConnectPeer(seed: UInt8) throws -> String {
    try NaclBox.keyPair(fromSecretKey: Data(repeating: seed, count: 32)).publicKey.map { String(format: "%02x", $0) }.joined()
}

private func tonConnectLink(peerSeed: UInt8) throws -> URL {
    var parts = URLComponents(string: "tc://")!
    parts.queryItems = [
        .init(name: "v", value: "2"), .init(name: "id", value: try tonConnectPeer(seed: peerSeed)),
        .init(name: "r", value: #"{"manifestUrl":"https://example.org/manifest.json","items":[{"name":"ton_addr"}]}"#)
    ]
    return try XCTUnwrap(parts.url)
}

private func tonConnectEvent(_ data: Data) throws -> [String: Any] {
    try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

final class LegacyTonConnectReplyDeliveryTests: XCTestCase {
    private let addressRequest = LegacyTonConnectConnectRequest(
        manifestUrl: URL(string: "https://example.org/manifest.json")!, items: [.init(name: "ton_addr", payload: nil)]
    )
    private let manifest = LegacyTonConnectManifest(url: URL(string: "https://example.org/app")!, name: "Original application", iconUrl: nil)

    /// An approved link whose reply the bridge refused keeps listening and sends the same bytes again; the user is
    /// asked once and hears nothing once it left.
    @MainActor
    func testAnApprovedReplyTheBridgeRefusedIsSentAgainWhileTheSessionListens() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let transport = TonConnectFlakyReplyTransport(failures: 2)
        let storage = TonConnectFakeSessionStore(values: [])
        var approvals = 0
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: storage, transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet },
            isEnabled: { true }, replyRetryNanoseconds: [50_000_000, 50_000_000, 50_000_000],
            reportError: { errors.append($0) }
        )
        await coordinator.activate()

        coordinator.open(try tonConnectLink(peerSeed: 5))
        try await tonConnectWaitUntil("The reply leaves on the third try") { transport.sent.count == 1 }
        try await tonConnectWaitUntil("The saved session listens") { transport.listens > 0 }
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(transport.attempts, 3)
        XCTAssertEqual(approvals, 1, "Decided once, never asked again")
        XCTAssertEqual(transport.manifestCalls, 1, "The link was not queued again")
        XCTAssertEqual(storage.values.count, 1)
        let reply = try XCTUnwrap(transport.sent.first)
        XCTAssertEqual(Set(transport.triedPayloads), [reply.data], "Every try carries the same decided reply")
        XCTAssertEqual(reply.topic, "connect")
        XCTAssertEqual(reply.session, storage.values.first)
        XCTAssertEqual(reply.bridge, URL(string: "https://bridge.example.org/bridge"))
        XCTAssertEqual(try tonConnectEvent(reply.data)["event"] as? String, "connect")
        XCTAssertTrue(errors.isEmpty, "Nothing to report once the reply left: \(errors)")
        coordinator.throttle()
    }

    /// A reply that never leaves is tried a bounded number of times; the session listens meanwhile, the user is told
    /// once and is not asked again.
    @MainActor
    func testAReplyThatNeverLeavesIsTriedABoundedNumberOfTimesAndTheUserIsToldOnce() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let transport = TonConnectFlakyReplyTransport(failures: .max)
        let storage = TonConnectFakeSessionStore(values: [])
        var approvals = 0
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: storage, transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return true }, walletLoader: { _ in wallet },
            isEnabled: { true }, replyRetryNanoseconds: [20_000_000, 20_000_000, 20_000_000],
            reportError: { errors.append($0) }
        )
        await coordinator.activate()

        coordinator.open(try tonConnectLink(peerSeed: 5))
        try await tonConnectWaitUntil("The saved session listens though its reply did not leave") { transport.listens > 0 }
        try await tonConnectWaitUntil("The user hears once every try failed") { !errors.isEmpty }
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(transport.attempts, 4, "The first try and three more, then it stops")
        XCTAssertEqual(Set(transport.triedPayloads).count, 1)
        XCTAssertTrue(transport.sent.isEmpty)
        XCTAssertEqual(storage.values.count, 1, "The approved session stays saved")
        XCTAssertEqual(errors.count, 1)
        guard case LegacyTonConnectError.transportFailed? = errors.first as? LegacyTonConnectError else {
            return XCTFail("Expected transportFailed, got \(errors)")
        }
        XCTAssertEqual(approvals, 1)
        XCTAssertEqual(transport.manifestCalls, 1)
        coordinator.throttle()
    }

    /// The same link arriving after it left the queue, while its decline is still being sent, is merged with it;
    /// once that reply left, a new arrival is a new request.
    @MainActor
    func testTheSameLinkOpenedWhileItsReplyIsSentAgainIsNotAskedAgain() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let transport = TonConnectFlakyReplyTransport(failures: 1)
        // Every send after the first, refused one waits for the gate.
        transport.gatedFromAttempt = 2
        var approvals = 0
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectFakeSessionStore(values: []), transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in approvals += 1; return false },
            walletLoader: { _ in wallet }, isEnabled: { true }, replyRetryNanoseconds: [10_000_000],
            reportError: { errors.append($0) }
        )
        await coordinator.activate()
        let url = try tonConnectLink(peerSeed: 5)
        let peer = try tonConnectPeer(seed: 5)

        coordinator.open(url)
        try await tonConnectWaitUntil("The decline's first try was refused") { approvals == 1 && transport.attempts >= 1 }
        // The queue is serial: another link is asked only after the first one left the queue.
        coordinator.open(try tonConnectLink(peerSeed: 6))
        try await tonConnectWaitUntil("The next link is asked") { approvals == 2 }
        coordinator.open(url)
        coordinator.open(url)
        try await tonConnectWaitUntil("The retried decline and the next reply wait at the gate") { transport.gate.waiting == 2 }

        transport.gate.open()
        try await tonConnectWaitUntil("Both declines left") { transport.sent.count == 2 }
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(approvals, 2, "The answered link was not asked about again")
        XCTAssertEqual(transport.manifestCalls, 2)
        let first = try XCTUnwrap(transport.sent.first { $0.session.clientId == peer })
        XCTAssertEqual(first.data, transport.triedPayloads.first, "The retry sends the refused decline unchanged")
        for reply in transport.sent {
            let event = try tonConnectEvent(reply.data)
            XCTAssertEqual(event["event"] as? String, "connect_error")
            XCTAssertEqual((event["payload"] as? [String: Any])?["code"] as? Int, 300)
        }
        XCTAssertEqual(transport.listens, 0, "A declined connection saves no session")
        XCTAssertTrue(errors.isEmpty)

        // The hold ends with the delivery task itself; until then an arrival is still merged.
        try await tonConnectWaitUntil("After its reply left, the link is a new request") {
            if approvals == 3 { return true }
            coordinator.open(url)
            return false
        }
        XCTAssertEqual(transport.manifestCalls, 3)
        coordinator.throttle()
    }

    /// Disconnecting the approved session ends its retries without a word.
    @MainActor
    func testADisconnectEndsTheRetriesQuietly() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let gate = TonConnectRetryGate()
        let transport = TonConnectFlakyReplyTransport(failures: .max)
        // On the main actor, like the retry and the transport's send: a wrong decision would show in the same job.
        let storage = TonConnectHookedSessionStore()
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: storage, transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, approval: { _, _ in true }, walletLoader: { _ in wallet }, isEnabled: { true },
            replyRetryNanoseconds: [1, 1, 1], replyRetryWait: gate.pass, reportError: { errors.append($0) }
        )
        await coordinator.activate()
        let response = try await coordinator.connect(
            walletId: wallet.metaId, clientId: try tonConnectTestSession().clientId, request: addressRequest,
            manifest: manifest, connectionType: "http"
        )
        XCTAssertEqual(try tonConnectEvent(response)["event"] as? String, "connect", "The decision stands")
        XCTAssertEqual(transport.attempts, 1)
        try await tonConnectWaitUntil("The retry waits") { gate.entered == 1 }

        try await coordinator.disconnect(try XCTUnwrap(storage.values.first))
        gate.releaseAll()
        try await tonConnectWaitUntil("The released retry decided") { gate.resumed == 1 }
        await coordinator.waitForDisconnectNotices()
        XCTAssertEqual(transport.triedTopics, ["connect", "disconnect"], "The application is told; the reply is not sent again")
        XCTAssertEqual(gate.entered, 1, "It stopped instead of waiting for another try")
        XCTAssertTrue(errors.isEmpty, "Stopping is not a failure to report: \(errors)")
        coordinator.throttle()
    }

    /// A disconnect that lands while a retry reads the session list (the read still saw the session) stops it.
    @MainActor
    func testADisconnectDuringTheSessionLookupStopsTheRetry() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let gate = TonConnectRetryGate()
        let transport = TonConnectFlakyReplyTransport(failures: .max)
        let storage = TonConnectHookedSessionStore()
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: storage, transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, approval: { _, _ in true }, walletLoader: { _ in wallet }, isEnabled: { true },
            replyRetryNanoseconds: [1, 1, 1], replyRetryWait: gate.pass, reportError: { errors.append($0) }
        )
        await coordinator.activate()
        _ = try await coordinator.connect(
            walletId: wallet.metaId, clientId: try tonConnectTestSession().clientId, request: addressRequest,
            manifest: manifest, connectionType: "http"
        )
        // The listener read the list once and now waits 10 s; the retry is parked: the next read is the retry's.
        try await tonConnectWaitUntil("The saved session listens") { transport.listens > 0 }
        try await tonConnectWaitUntil("The retry waits") { gate.entered == 1 }
        let session = try XCTUnwrap(storage.values.first)
        storage.arm { try? await coordinator.disconnect(session) }
        gate.releaseAll()
        try await tonConnectWaitUntil("The retry read the list while the session was disconnected") { storage.hookFired }
        await coordinator.waitForDisconnectNotices()

        XCTAssertEqual(
            transport.triedTopics, ["connect", "disconnect"],
            "Only the disconnect notice follows; no reply is sent for a session disconnected during the lookup"
        )
        XCTAssertEqual(gate.entered, 1)
        XCTAssertTrue(storage.values.isEmpty)
        XCTAssertTrue(errors.isEmpty, "Stopping is not a failure to report: \(errors)")
        coordinator.throttle()
    }

    /// A newer decision for the same session supersedes an older reply still being sent again.
    @MainActor
    func testANewerReplyForTheSessionEndsTheOlderRetry() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let gate = TonConnectRetryGate()
        let transport = TonConnectFlakyReplyTransport(failures: 1)
        var answers = [true, false]
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectHookedSessionStore(), transport: transport, replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in answers.removeFirst() },
            walletLoader: { _ in wallet }, isEnabled: { true }, replyRetryNanoseconds: [1, 1, 1],
            replyRetryWait: gate.pass, reportError: { errors.append($0) }
        )
        await coordinator.activate()
        let clientId = try tonConnectTestSession().clientId
        let approved = try await coordinator.connect(
            walletId: wallet.metaId, clientId: clientId, request: addressRequest, manifest: manifest, connectionType: "http"
        )
        try await tonConnectWaitUntil("The approval's retry waits") { gate.entered == 1 }
        let declined = try await coordinator.connect(
            walletId: wallet.metaId, clientId: clientId, request: addressRequest, manifest: manifest, connectionType: "http"
        )
        XCTAssertEqual(transport.sent.map { $0.data }, [declined], "The newer decision left at once")

        gate.releaseAll()
        try await tonConnectWaitUntil("The released retry decided") { gate.resumed == 1 }
        XCTAssertEqual(transport.sent.map { $0.data }, [declined], "The superseded approval is not sent after it")
        XCTAssertEqual(transport.attempts, 2)
        XCTAssertEqual(gate.entered, 1)
        XCTAssertEqual(try tonConnectEvent(approved)["event"] as? String, "connect")
        XCTAssertEqual(try tonConnectEvent(declined)["event"] as? String, "connect_error")
        XCTAssertTrue(errors.isEmpty)
        coordinator.throttle()
    }

    /// The application's disconnect, its replay and the user's disconnect each tell the handler before the session
    /// is removed, so a reply still being sent for it ends first.
    func testEveryDisconnectTellsTheHandlerBeforeRemovingTheSession() async throws {
        let log = TonConnectEventLog()
        let session = try tonConnectTestSession()
        let other = try tonConnectTestSession(id: "other-session")
        let storage = TonConnectLoggingSessionStore(values: [session, other], log: log)
        let handler = TonConnectDisconnectRecordingHandler(log: log)
        let service = LegacyTonConnectService(
            store: storage, replies: LegacyTonConnectReplyStore(keystore: TonConnectFixtureKeychain()),
            transport: TonConnectFakeTransport(), legacyEventId: { nil }
        )
        await service.set(handler: handler)
        let disconnect = Data(#"{"id":"7","method":"disconnect","params":[]}"#.utf8)

        storage.failRemovals = 1
        do {
            _ = try await service.handle(disconnect, session: session, network: "-239")
            XCTFail("No acknowledgement while the session is still stored")
        } catch {}
        _ = try await service.handle(disconnect, session: session, network: "-239")
        XCTAssertEqual(log.events, ["willDisconnect", "remove failed", "willDisconnect", "remove"])

        try await service.disconnect(other)
        XCTAssertEqual(log.events.suffix(2), ["willDisconnect", "remove"])
        XCTAssertTrue(storage.values.isEmpty)
    }

    /// A veto that arrives while a retry reads the session list still stops that retry.
    @MainActor
    func testAVetoDuringTheSessionLookupStopsTheRetry() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let enabled = TonConnectLockedFlag(true)
        let gate = TonConnectRetryGate()
        let transport = TonConnectFlakyReplyTransport(failures: .max)
        let storage = TonConnectHookedSessionStore()
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: storage, transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, approval: { _, _ in true }, walletLoader: { _ in wallet },
            isEnabled: { enabled.value }, replyRetryNanoseconds: [1, 1, 1], replyRetryWait: gate.pass,
            reportError: { errors.append($0) }
        )
        await coordinator.activate()
        _ = try await coordinator.connect(
            walletId: wallet.metaId, clientId: try tonConnectTestSession().clientId, request: addressRequest,
            manifest: manifest, connectionType: "http"
        )
        // The listener read the list once and now waits 10 s; the retry is parked: the next read is the retry's.
        try await tonConnectWaitUntil("The saved session listens") { transport.listens > 0 }
        try await tonConnectWaitUntil("The retry waits") { gate.entered == 1 }
        storage.arm { enabled.value = false }
        gate.releaseAll()
        try await tonConnectWaitUntil("The retry read the session list") { storage.hookFired }

        XCTAssertEqual(transport.attempts, 1, "Vetoed during the lookup: nothing more is sent")
        XCTAssertEqual(gate.entered, 1)
        XCTAssertTrue(errors.isEmpty, "A vetoed reply is not a failure to report: \(errors)")
        XCTAssertEqual(storage.values.count, 1, "The session and its keys stay")
        coordinator.throttle()
    }

    /// A wallet throttled while the first try is on its way starts no listener; the decided reply still leaves.
    @MainActor
    func testAThrottleWhileTheReplyIsSentStartsNoListener() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let transport = TonConnectFlakyReplyTransport(failures: 1)
        transport.gatedFromAttempt = 1
        let storage = TonConnectHookedSessionStore()
        var errors: [Error] = []
        let coordinator = LegacyTonConnectCoordinator(
            store: storage, transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, approval: { _, _ in true }, walletLoader: { _ in wallet }, isEnabled: { true },
            replyRetryNanoseconds: [10_000_000], reportError: { errors.append($0) }
        )
        await coordinator.activate()
        let connecting = Task { @MainActor in
            try await coordinator.connect(
                walletId: wallet.metaId, clientId: try tonConnectTestSession().clientId, request: self.addressRequest,
                manifest: self.manifest, connectionType: "http"
            )
        }
        try await tonConnectWaitUntil("The first try is on its way") { transport.gate.waiting == 1 }
        coordinator.throttle()
        // The throttle runs on the next main turn and stops the service from a task; a later service call queues
        // behind that stop.
        try await Task.sleep(nanoseconds: 300_000_000)
        _ = try? await coordinator.selectedSessions()
        let readsBeforeRelease = storage.reads
        transport.gate.open()
        let response = try await connecting.value

        try await tonConnectWaitUntil("The decided reply leaves on the retry") { transport.sent.count == 1 }
        XCTAssertEqual(transport.sent.first?.data, response)
        // Starting listeners reads the session list whatever the stop's timing; only the retry's lookup may read it.
        XCTAssertEqual(storage.reads - readsBeforeRelease, 1, "A throttled wallet starts no listener")
        XCTAssertEqual(transport.listens, 0)
        XCTAssertEqual(storage.values.count, 1, "The approved session is saved for the next activation")
        XCTAssertTrue(errors.isEmpty)
    }
}

// MARK: - The screen-authorization PIN closed by the app going to the background (Codex rounds 6 and 8)

private final class TonConnectIdlePinInteractor: LocalAuthInteractorInputProtocol {
    var allowManualBiometryAuth: Bool { false }
    var availableBiometryType: AvailableBiometryType { .none }
    private(set) var cancels = 0
    func startAuth(with _: LocalAuthInteractorOutputProtocol) {}
    func process(pin _: String) {}
    func cancelAuth() { cancels += 1 }
}

private final class TonConnectOutcomeWireframe: ScreenAuthorizationWireframeProtocol {
    private(set) var outcomes: [ScreenAuthorizationOutcome] = []
    func showAuthorizationCompletion(with result: Bool) { outcomes.append(result ? .authorized : .declined) }
    func showAuthorizationCompletion(outcome: ScreenAuthorizationOutcome) { outcomes.append(outcome) }
}

private final class TonConnectBoolWireframe: ScreenAuthorizationWireframeProtocol {
    private(set) var results: [Bool] = []
    func showAuthorizationCompletion(with result: Bool) { results.append(result) }
}

private final class TonConnectTestAuthorizer: AuthorizationPresentable {
    func createAuthorizationView(with wireframe: ScreenAuthorizationWireframeProtocol, cancellable: Bool) -> PinSetupViewProtocol? {
        PinViewFactory.createScreenAuthorizationView(
            with: wireframe, cancellable: cancellable, interactor: TonConnectIdlePinInteractor(),
            localizationManager: LocalizationManager.shared
        )
    }
}

private final class TonConnectHostController: UIViewController, ControllerBackedProtocol {}

final class LegacyTonConnectPinBackgroundTests: XCTestCase {
    private var window: UIWindow?
    private var previousKeyWindow: UIWindow?

    override func tearDown() {
        window?.rootViewController?.dismiss(animated: false)
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        previousKeyWindow?.makeKey()
        previousKeyWindow = nil
        super.tearDown()
    }

    @MainActor
    private func host() async throws -> TonConnectHostController {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive }), "The test host needs an active scene")
        previousKeyWindow = scene.windows.first(where: \.isKeyWindow)
        let root = TonConnectHostController()
        root.view.backgroundColor = .systemBackground
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = root
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        self.window = window
        try await tonConnectWaitUntil("The host is on screen") { root.view.window === window && root.transitionCoordinator == nil }
        return root
    }

    @MainActor
    private func settled<T: UIViewController>(_ type: T.Type, over presenter: UIViewController) async throws -> T {
        try await tonConnectWaitUntil("\(T.self) is on screen") {
            guard let shown = presenter.presentedViewController as? T else { return false }
            return shown.view.window != nil && !shown.isBeingPresented && shown.transitionCoordinator == nil
        }
        return try XCTUnwrap(presenter.presentedViewController as? T)
    }

    @MainActor
    private func approve(_ sheet: LegacyTonConnectApprovalViewController) throws {
        func buttons(_ view: UIView) -> [UIButton] { view.subviews.flatMap { ($0 as? UIButton).map { [$0] } ?? buttons($0) } }
        let approve = try XCTUnwrap(buttons(sheet.view).first { $0.accessibilityIdentifier == "tonconnect.approve" })
        approve.sendActions(for: .touchUpInside)
    }

    private func postBackgroundAndReturn() {
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: UIApplication.shared)
        NotificationCenter.default.post(name: UIApplication.willEnterForegroundNotification, object: UIApplication.shared)
    }

    /// The presenter tells the app leaving (unanswered) from the user's Cancel (declined); a wireframe that only
    /// knows Bool hears `false` for both, as before.
    @MainActor
    func testScreenAuthorizationTellsABackgroundCloseFromACancel() async throws {
        let outcomeWireframe = TonConnectOutcomeWireframe()
        let backgrounded = ScreenAuthorizationPresenter(wireframe: outcomeWireframe, interactor: TonConnectIdlePinInteractor())
        backgrounded.didLoad(view: CovJOnPinView())
        let cancelledWireframe = TonConnectOutcomeWireframe()
        let cancelled = ScreenAuthorizationPresenter(wireframe: cancelledWireframe, interactor: TonConnectIdlePinInteractor())
        cancelled.didLoad(view: CovJOnPinView())
        cancelled.cancel()
        let boolWireframe = TonConnectBoolWireframe()
        let legacy = ScreenAuthorizationPresenter(wireframe: boolWireframe, interactor: TonConnectIdlePinInteractor())
        legacy.didLoad(view: CovJOnPinView())

        postBackgroundAndReturn()

        try await tonConnectWaitUntil("The app leaving is no answer") { outcomeWireframe.outcomes == [.unanswered] }
        try await tonConnectWaitUntil("A Bool-only wireframe hears false") { boolWireframe.results == [false] }
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(outcomeWireframe.outcomes, [.unanswered], "Reported once")
        XCTAssertEqual(cancelledWireframe.outcomes, [.declined], "A finished PIN ignores the later background")
        XCTAssertEqual(boolWireframe.results, [false], "Callers that only take Bool are unchanged")

        let authorizedWireframe = TonConnectOutcomeWireframe()
        let authorized = ScreenAuthorizationPresenter(wireframe: authorizedWireframe, interactor: TonConnectIdlePinInteractor())
        authorized.didLoad(view: CovJOnPinView())
        authorized.didCompleteAuth()
        try await tonConnectWaitUntil("A completed PIN authorizes") { authorizedWireframe.outcomes == [.authorized] }
        withExtendedLifetime([backgrounded, cancelled, legacy, authorized]) {}
    }

    /// Through `AuthorizationPresentable`: the Bool API still reports `false` when the app leaves, while the outcome
    /// API reports it unanswered and a Cancel declined.
    @MainActor
    func testAuthorizationPresentableKeepsBoolCallersAndReportsUnansweredToOutcomeCallers() async throws {
        let root = try await host()
        let authorizer = TonConnectTestAuthorizer()

        var results: [Bool] = []
        authorizer.authorize(animated: true, cancellable: true, from: root) { results.append($0) }
        _ = try await settled(PinSetupViewController.self, over: root)
        postBackgroundAndReturn()
        try await tonConnectWaitUntil("The Bool caller hears false") { results == [false] }
        try await tonConnectWaitUntil("The PIN closed") { root.presentedViewController == nil && root.transitionCoordinator == nil }

        var outcomes: [ScreenAuthorizationOutcome] = []
        authorizer.authorizeWithOutcome(animated: true, cancellable: true, from: root) { outcomes.append($0) }
        _ = try await settled(PinSetupViewController.self, over: root)
        postBackgroundAndReturn()
        try await tonConnectWaitUntil("The outcome caller hears unanswered") { outcomes == [.unanswered] }
        try await tonConnectWaitUntil("The PIN closed") { root.presentedViewController == nil && root.transitionCoordinator == nil }

        authorizer.authorizeWithOutcome(animated: true, cancellable: true, from: root) { outcomes.append($0) }
        let pin = try await settled(PinSetupViewController.self, over: root)
        pin.actionCancel()
        try await tonConnectWaitUntil("Cancel declines") { outcomes == [.unanswered, .declined] }
        try await tonConnectWaitUntil("The PIN closed") { root.presentedViewController == nil && root.transitionCoordinator == nil }
    }

    /// The real approval sheet and PIN: the app leaving over the PIN sends no decline and leaves the request to be
    /// asked again; the user's Cancel on the PIN still declines.
    @MainActor
    func testATonApprovalWhosePinClosedWithTheAppSendsNoDecline() async throws {
        let root = try await host()
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let transport = TonConnectFlakyReplyTransport(failures: 0)
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectFakeSessionStore(values: []), transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, walletLoader: { _ in wallet }, isEnabled: { true },
            authorizationViewFactory: {
                PinViewFactory.createScreenAuthorizationView(
                    with: $0, cancellable: $1, interactor: TonConnectIdlePinInteractor(),
                    localizationManager: LocalizationManager.shared
                )
            },
            reportError: { XCTFail("Unexpected error \($0)") }
        )
        await coordinator.activate()
        let request = LegacyTonConnectConnectRequest(
            manifestUrl: URL(string: "https://example.org/manifest.json")!, items: [.init(name: "ton_addr", payload: nil)]
        )
        let manifest = LegacyTonConnectManifest(url: URL(string: "https://example.org/app")!, name: "Original application", iconUrl: nil)
        let clientId = try tonConnectTestSession().clientId
        func connecting() -> Task<Result<Data, Error>, Never> {
            Task { @MainActor in
                do {
                    return .success(try await coordinator.connect(
                        walletId: wallet.metaId, clientId: clientId, request: request, manifest: manifest, connectionType: "http"
                    ))
                } catch {
                    return .failure(error)
                }
            }
        }

        let first = connecting()
        let sheet = try await settled(LegacyTonConnectApprovalViewController.self, over: root)
        try approve(sheet)
        _ = try await settled(PinSetupViewController.self, over: sheet)
        postBackgroundAndReturn()
        guard case let .failure(error) = await first.value, case LegacyTonConnectError.busy? = error as? LegacyTonConnectError else {
            return XCTFail("An unanswered approval is not a decision")
        }
        XCTAssertEqual(transport.attempts, 0, "No decline for a request the user never answered")
        try await tonConnectWaitUntil("The sheet and PIN closed") { root.presentedViewController == nil && root.transitionCoordinator == nil }

        let second = connecting()
        let again = try await settled(LegacyTonConnectApprovalViewController.self, over: root)
        try approve(again)
        let pin = try await settled(PinSetupViewController.self, over: again)
        pin.actionCancel()
        guard case let .success(declined) = await second.value else {
            return XCTFail("Cancel on the PIN is the user's decline")
        }
        XCTAssertEqual(try tonConnectEvent(declined)["event"] as? String, "connect_error")
        XCTAssertEqual(transport.sent.count, 1)
        XCTAssertEqual(transport.sent.first?.data, declined)
        try await tonConnectWaitUntil("The sheet and PIN closed") { root.presentedViewController == nil && root.transitionCoordinator == nil }
        coordinator.throttle()
    }

    /// Through the link queue: the PIN closed with the app leaves the link queued; it is asked again on the next
    /// settled screen, and the user's Cancel then sends one decline.
    @MainActor
    func testALinkWhosePinClosedWithTheAppIsAskedAgainAndDeclinedOnce() async throws {
        let root = try await host()
        let keys = TonConnectFixtureKeychain()
        let wallet = try tonConnectNativeWallet(keys)
        let transport = TonConnectFlakyReplyTransport(failures: 0)
        let coordinator = LegacyTonConnectCoordinator(
            store: TonConnectFakeSessionStore(values: []), transport: transport, replies: .init(keystore: keys), keystore: keys,
            selectedWallet: { wallet }, walletLoader: { _ in wallet }, isEnabled: { true },
            authorizationViewFactory: {
                PinViewFactory.createScreenAuthorizationView(
                    with: $0, cancellable: $1, interactor: TonConnectIdlePinInteractor(),
                    localizationManager: LocalizationManager.shared
                )
            },
            reportError: { XCTFail("Unexpected error \($0)") }
        )
        await coordinator.activate()

        coordinator.open(try tonConnectLink(peerSeed: 5))
        let sheet = try await settled(LegacyTonConnectApprovalViewController.self, over: root)
        try approve(sheet)
        _ = try await settled(PinSetupViewController.self, over: sheet)
        postBackgroundAndReturn()
        try await tonConnectWaitUntil("The unanswered sheet closed") { root.presentedViewController !== sheet }
        XCTAssertEqual(transport.attempts, 0, "No decline for a request the user never answered")

        let again = try await settled(LegacyTonConnectApprovalViewController.self, over: root)
        XCTAssertFalse(again === sheet)
        try approve(again)
        let pin = try await settled(PinSetupViewController.self, over: again)
        pin.actionCancel()
        try await tonConnectWaitUntil("The user's Cancel declines") { transport.sent.count == 1 }
        try await tonConnectWaitUntil("The sheet and PIN closed") { root.presentedViewController == nil && root.transitionCoordinator == nil }
        try await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertEqual(transport.attempts, 1, "One decline, sent once")
        XCTAssertEqual(transport.manifestCalls, 2, "Asked again after no answer, then never again")
        XCTAssertNil(root.presentedViewController)
        let event = try tonConnectEvent(try XCTUnwrap(transport.sent.first).data)
        XCTAssertEqual(event["event"] as? String, "connect_error")
        coordinator.throttle()
    }
}
