import UIKit
import WebKit
import CoreData
import CryptoKit
import Foundation
import RobinHood
import SoraKeystore
import TonSwift
import TweetNacl
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

final class LegacyTonConnectStoreTests: XCTestCase {
    func testReleasedSessionsReloadWithOriginalKeysAndMissingTypeWithoutRewritingRows() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("legacy.sqlite")
        let fixture = try TonConnectFixtureCoreDataService(url: file)
        let http = try tonConnectTestSession(id: "old-http")
        let js = try tonConnectTestSession(id: "old-js", clientId: UUID().uuidString, type: "js")
        try fixture.insert(http, missingType: true)
        try fixture.insert(js, missingType: true)
        var malformed = try fixture.snapshot()
        XCTAssertEqual(malformed.count, 2)
        let store = LegacyTonConnectStore(service: fixture)
        let sessions = try await store.sessions()
        XCTAssertEqual(Set(sessions.map(\.identifier)), [http.identifier, js.identifier])
        XCTAssertEqual(sessions.first(where: { $0.identifier == http.identifier })?.connectionType, "http")
        XCTAssertEqual(sessions.first(where: { $0.identifier == js.identifier })?.connectionType, "js")
        XCTAssertEqual(sessions.first(where: { $0.identifier == http.identifier })?.privateKey, http.privateKey)
        XCTAssertEqual(try fixture.snapshot(), malformed)
        try fixture.close()
        let reopened = try TonConnectFixtureCoreDataService(url: file)
        let restored = try await LegacyTonConnectStore(service: reopened).sessions()
        XCTAssertEqual(restored.count, 2)
        XCTAssertEqual(restored.first(where: { $0.identifier == js.identifier })?.publicKey, js.publicKey)
        malformed = try reopened.snapshot()
        XCTAssertFalse(malformed.contains { $0["connectionType"] != nil })
        try reopened.close()
    }

    func testSessionSaveConflictAndDisconnectPreserveOtherLegacyRows() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let store = LegacyTonConnectStore(service: fixture)
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
        try await store.remove(original)
    }

    func testInvalidSessionDoesNotHideOtherSessionsAndBridgeUsesRetainedChain() async throws {
        let fixture = try TonConnectFixtureCoreDataService()
        let original = try tonConnectTestSession()
        try fixture.insert(original)
        let invalid = LegacyTonConnectSession(identifier: "invalid", walletId: original.walletId, clientId: "unknown", appUrl: original.appUrl, name: original.name,
                                              iconUrl: nil, publicKey: Data(repeating: 0, count: 32), privateKey: original.privateKey, connectionType: "future")
        try fixture.insert(invalid)
        let store = LegacyTonConnectStore(service: fixture)
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
    init(values: [LegacyTonConnectSession]) { self.values = values }
    func sessions() async throws -> [LegacyTonConnectSession] { values }
    func save(_ session: LegacyTonConnectSession) async throws { if !values.contains(session) { values.append(session) } }
    func remove(_ session: LegacyTonConnectSession) async throws { values.removeAll { $0 == session } }
    func bridgeURL(network _: String) async throws -> URL { URL(string: "https://bridge.example.org/bridge")! }
}

private final class TonConnectFakeTransport: LegacyTonConnectBridgeTransporting {
    var onListen: (() -> Void)?
    var sent: [(Data, LegacyTonConnectSession, URL, String)] = []
    var manifestValue: LegacyTonConnectManifest?
    func manifest(at url: URL) async throws -> LegacyTonConnectManifest { manifestValue ?? .init(url: url, name: "Fixture", iconUrl: nil) }
    func send(_ data: Data, session: LegacyTonConnectSession, bridge: URL, topic: String) async throws {
        sent.append((data, session, bridge, topic))
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

final class LegacyTonConnectCoordinatorTests: XCTestCase {
    private func wallet(_ keys: TonConnectFixtureKeychain) throws -> MetaAccountModel {
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

    @MainActor
    func testDamagedExistingNativeSecretDoesNotReplaceItOnReconnect() async throws {
        let keys = TonConnectFixtureKeychain()
        let wallet = try wallet(keys)
        let tag = KeystoreTagV2.tonSecretKeyTagForMetaId(wallet.metaId)
        keys.values[tag] = Data(repeating: 0, count: 64)
        let storage = TonConnectFakeSessionStore(values: [])
        let coordinator = LegacyTonConnectCoordinator(store: storage, transport: TonConnectFakeTransport(), replies: .init(keystore: keys),
            keystore: keys, selectedWallet: { wallet }, approval: { _, _ in true }, walletLoader: { _ in wallet })
        await coordinator.activate()
        do { _ = try await coordinator.connect(walletId: wallet.metaId, clientId: "", request: request, manifest: manifest, connectionType: "js"); XCTFail("Damaged original key") } catch {}
        XCTAssertEqual(keys.values[tag], Data(repeating: 0, count: 64))
        XCTAssertTrue(storage.values.isEmpty)
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
        var completions: [Bool] = []
        controller.completion = { completions.append($0) }
        controller.finish(approved: false)
        controller.finish(approved: true)
        XCTAssertEqual(completions, [false])
    }

    @MainActor
    func testRealWebKitBridgePublishesReleasedProviderAndHandlesStructuredReplies() async throws {
        let coordinator = LegacyTonConnectCoordinator(store: TonConnectFakeSessionStore(values: []), transport: TonConnectFakeTransport(),
                                                       replies: .init(keystore: TonConnectFixtureKeychain()), selectedWallet: { nil })
        let controller = LegacyTonConnectBrowserViewController(url: URL(string: "https://example.org")!, coordinator: coordinator)
        controller.loadViewIfNeeded()
        controller.webView.stopLoading()
        let loaded = expectation(description: "Synthetic WKWebView page")
        let delegate = TonConnectTestNavigationDelegate { loaded.fulfill() }
        controller.webView.navigationDelegate = delegate
        controller.webView.loadHTMLString("<!doctype html><html><body>Public TonConnect fixture</body></html>", baseURL: URL(string: "https://example.org")!)
        await fulfillment(of: [loaded], timeout: 10)
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

private final class TonConnectTestNavigationDelegate: NSObject, WKNavigationDelegate {
    private let loaded: () -> Void
    init(loaded: @escaping () -> Void) { self.loaded = loaded }
    func webView(_: WKWebView, didFinish _: WKNavigation!) { loaded() }
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
