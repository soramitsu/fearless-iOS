import AuthenticationServices
@testable import fearless
import UIKit
import XCTest

@MainActor
final class PasskeyBackupOwnerAuthenticationTests: XCTestCase {
    private let endpoint = URL(string: "https://backup.fearlesswallet.io")!
    private let now: Int64 = 1000

    func testDelayedCancellationCannotFinishTheNextCeremony() {
        var gate = PasskeyOwnerAuthAttemptGate()
        let first = UUID(), second = UUID()
        XCTAssertTrue(gate.begin(first))
        XCTAssertTrue(gate.finish(first))
        XCTAssertTrue(gate.begin(second))
        XCTAssertFalse(gate.finish(first))
        XCTAssertEqual(gate.activeID, second)
        XCTAssertTrue(gate.finish(second))
    }

    func testDiscoverableCeremonySendsOnlyPublicAssertionAndAcceptsBoundSession() async throws {
        let transport = OwnerAuthenticationTransportFixture()
        transport.responses = [
            .init(statusCode: 200, body: challengeBody()),
            .init(statusCode: 200, body: sessionBody())
        ]
        let source = try HTTPPasskeyOwnerAuthSource(
            baseURL: endpoint, transport: transport, nowUnixSeconds: { self.now }
        )
        let challenge = try await source.begin()
        XCTAssertEqual(challenge.challenge, Data(repeating: 7, count: 32))
        XCTAssertEqual(challenge.expiresAtUnixSeconds, 1120)
        XCTAssertEqual(String(reflecting: challenge), "PasskeyOwnerAuthChallenge(<redacted>)")
        XCTAssertEqual(Array(Mirror(reflecting: challenge).children).count, 0)

        let assertion = try publicAssertion()
        let session = try await source.complete(challenge: challenge, assertion: assertion)
        XCTAssertEqual(session.ownerSubject, ownerSubject)
        XCTAssertEqual(session.backupNamespace, backupNamespace)
        XCTAssertEqual(session.expiresAtUnixSeconds, 1600)
        XCTAssertEqual(String(reflecting: assertion), "PasskeyBackupOwnerPublicAssertion(<redacted>)")
        XCTAssertEqual(Array(Mirror(reflecting: assertion).children).count, 0)

        XCTAssertEqual(transport.requests.map(\.method), ["POST", "POST"])
        XCTAssertEqual(transport.requests.map(\.url.path), [
            "/api/passkey-backup/v1/owner/authentication/challenge",
            "/api/passkey-backup/v1/owner/authentication/complete"
        ])
        XCTAssertEqual(transport.requests[0].body, Data(#"{"schemaVersion":1,"platform":"ios"}"#.utf8))
        XCTAssertEqual(transport.requests[0].headers["Cache-Control"], "no-store")
        XCTAssertNil(transport.requests[0].headers["Authorization"])
        XCTAssertNil(transport.requests[1].headers["Authorization"])
        let complete = try XCTUnwrap(transport.requests[1].body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: complete) as? [String: Any])
        XCTAssertEqual(Set(object.keys), ["schemaVersion", "ceremonyId", "credential"])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertEqual(object["ceremonyId"] as? String, ceremonyID)
        let credential = try XCTUnwrap(object["credential"] as? [String: Any])
        XCTAssertEqual(Set(credential.keys), [
            "id", "rawId", "response", "type", "clientExtensionResults", "authenticatorAttachment"
        ])
        let fields = try XCTUnwrap(credential["response"] as? [String: Any])
        XCTAssertEqual(Set(fields.keys), [
            "clientDataJSON", "authenticatorData", "signature", "userHandle"
        ])
        let serialized = try XCTUnwrap(String(data: complete, encoding: .utf8))
        XCTAssertFalse(serialized.localizedCaseInsensitiveContains("prf"))
        XCTAssertFalse(serialized.contains("fixture-local-secret"))
    }

    func testRejectsAmbiguousStaleAndSubstitutedAuthenticationChallenge() async throws {
        let original = try XCTUnwrap(String(data: challengeBody(), encoding: .utf8))
        let cases = [
            original.replacingOccurrences(of: #""challenge":"#, with: #""challenge":"bad","challenge":"#),
            original.replacingOccurrences(of: #""challenge":"#, with: #""\u0063hallenge":"bad","challenge":"#),
            original.replacingOccurrences(of: #""kind":"authentication""#, with: #""kind":"bootstrap""#),
            original.replacingOccurrences(of: #""platform":"ios""#, with: #""platform":"android""#),
            original.replacingOccurrences(of: #""subject":null"#, with: #""subject":"owner:bogus""#),
            original.replacingOccurrences(of: #""expiresAt":1120"#, with: #""expiresAt":1000"#),
            original.replacingOccurrences(of: #""expiresAt":1120"#, with: #""expiresAt":999999"#),
            original.replacingOccurrences(of: #""expiresAt":1120"#, with: #""expiresAt":"1120""#),
            original.replacingOccurrences(of: #""rpId":"fearlesswallet.io""#, with: #""rpId":"evil.example""#),
            original.replacingOccurrences(of: #""challenge":"#, with: #""unexpected":null,"challenge":"#),
            original + "{}"
        ]
        for body in cases {
            XCTAssertNotEqual(body, original)
            let transport = OwnerAuthenticationTransportFixture()
            transport.responses = [.init(statusCode: 200, body: Data(body.utf8))]
            let source = try HTTPPasskeyOwnerAuthSource(
                baseURL: endpoint, transport: transport, nowUnixSeconds: { self.now }
            )
            do {
                _ = try await source.begin()
                XCTFail("Untrusted owner challenge was accepted")
            } catch {
                XCTAssertTrue(error is PasskeyBackupOwnerAuthenticationError)
            }
            XCTAssertEqual(transport.requests.count, 1)
        }
    }

    func testRejectsAmbiguousOrSubstitutedSessionAndExpiredLocalChallenge() async throws {
        let original = try XCTUnwrap(String(data: sessionBody(), encoding: .utf8))
        let cases = [
            original.replacingOccurrences(of: #""sessionToken":"#, with: #""sessionToken":"bad","sessionToken":"#),
            original.replacingOccurrences(of: #""subject":"#, with: #""subject":"owner:bogus","subject":"#),
            original.replacingOccurrences(of: #""namespace":"#, with: #""namespace":"backup:bogus","namespace":"#),
            original.replacingOccurrences(of: #""platform":"ios""#, with: #""platform":"android""#),
            original.replacingOccurrences(of: #""generation":0"#, with: #""generation":"0""#),
            original.replacingOccurrences(of: #""expiresAt":1600"#, with: #""expiresAt":2000"#),
            original.replacingOccurrences(of: #""sessionToken":"#, with: #""unexpected":null,"sessionToken":"#),
            original + "{}"
        ]
        for body in cases {
            XCTAssertNotEqual(body, original)
            let transport = OwnerAuthenticationTransportFixture()
            transport.responses = [.init(statusCode: 200, body: Data(body.utf8))]
            let source = try HTTPPasskeyOwnerAuthSource(
                baseURL: endpoint, transport: transport, nowUnixSeconds: { self.now }
            )
            await assertAuthenticationFailure {
                _ = try await source.complete(challenge: self.challenge(), assertion: self.publicAssertion())
            }
            XCTAssertEqual(transport.requests.count, 1)
        }

        let transport = OwnerAuthenticationTransportFixture()
        let source = try HTTPPasskeyOwnerAuthSource(
            baseURL: endpoint, transport: transport, nowUnixSeconds: { 1120 }
        )
        await assertAuthenticationFailure {
            _ = try await source.complete(challenge: self.challenge(), assertion: self.publicAssertion())
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    @available(iOS 18.0, *)
    func testCoordinatorPassesFreshPublicAssertionToOwnerAuthority() async throws {
        let transport = OwnerAuthenticationTransportFixture()
        transport.responses = [
            .init(statusCode: 200, body: challengeBody()),
            .init(statusCode: 200, body: sessionBody())
        ]
        let source = try HTTPPasskeyOwnerAuthSource(
            baseURL: endpoint, transport: transport, nowUnixSeconds: { self.now }
        )
        let executor = try OwnerAuthenticationExecutorFixture(assertion: publicAssertion())
        let coordinator = PasskeyOwnerAuthCoordinator(
            source: source, executor: executor, isReleaseEnabled: true
        )
        let session = try await coordinator.authenticate()
        XCTAssertEqual(session.ownerSubject, ownerSubject)
        XCTAssertEqual(executor.calls, 1)
        XCTAssertEqual(transport.requests.count, 2)
    }

    @available(iOS 18.0, *)
    func testNativeRequestIsDiscoverableAndReleaseDisabledCoordinatorDoesNotCallSource() async throws {
        let request = try PasskeyOwnerAuthRequestFactory.assertion(challenge())
        XCTAssertEqual(request.allowedCredentials.count, 0)
        XCTAssertEqual(request.userVerificationPreference, .required)
        let transport = OwnerAuthenticationTransportFixture()
        let source = try HTTPPasskeyOwnerAuthSource(
            baseURL: endpoint, transport: transport, nowUnixSeconds: { self.now }
        )
        let executor = try OwnerAuthenticationExecutorFixture(assertion: publicAssertion())
        let coordinator = PasskeyOwnerAuthCoordinator(
            source: source, executor: executor
        )
        do {
            _ = try await coordinator.authenticate()
            XCTFail("Compiled-off owner authentication was accepted")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled)
        }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(executor.calls, 0)

        let native = ASPasskeyOwnerAuthExecutor(
            isReleaseEnabled: false, presentationAnchor: { UIWindow() }
        )
        do {
            _ = try await native.perform(challenge: challenge())
            XCTFail("Compiled-off native ceremony was accepted")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled)
        }

        XCTAssertThrowsError(try HTTPPasskeyOwnerAuthSource(
            baseURL: XCTUnwrap(URL(string: "http://backup.fearlesswallet.io")), transport: transport
        ))
        XCTAssertThrowsError(try PasskeyOwnerAuthChallenge(
            ceremonyId: "ceremony.bad", challenge: Data(repeating: 7, count: 32),
            expiresAtUnixSeconds: 1120
        ))
        XCTAssertThrowsError(try PasskeyBackupOwnerPublicAssertion(
            credentialID: Data(repeating: 3, count: 32),
            clientDataJSON: Data(#"{"type":"webauthn.get"}"#.utf8),
            authenticatorData: Data(repeating: 4, count: 37),
            signature: Data(repeating: 5, count: 64), userHandle: Data()
        ))
    }

    private var ceremonyID: String {
        "ceremony." + b64(Data(repeating: 6, count: 32))
    }

    private var ownerSubject: String {
        "owner:" + b64(Data(repeating: 1, count: 32))
    }

    private var backupNamespace: String {
        "backup:" + b64(Data(repeating: 2, count: 32))
    }

    private func challenge() throws -> PasskeyOwnerAuthChallenge {
        try PasskeyOwnerAuthChallenge(
            ceremonyId: ceremonyID, challenge: Data(repeating: 7, count: 32),
            expiresAtUnixSeconds: 1120
        )
    }

    private func publicAssertion() throws -> PasskeyBackupOwnerPublicAssertion {
        try PasskeyBackupOwnerPublicAssertion(
            credentialID: Data(repeating: 3, count: 32),
            clientDataJSON: Data(#"{"type":"webauthn.get","challenge":"fixture"}"#.utf8),
            authenticatorData: Data(repeating: 4, count: 37),
            signature: Data(repeating: 5, count: 64),
            userHandle: Data(repeating: 8, count: 32)
        )
    }

    private func challengeBody() -> Data {
        let json = """
        {"ceremonyId":"\(ceremonyID)",
        "kind":"authentication",
        "challenge":"\(b64(Data(repeating: 7, count: 32)))",
        "rpId":"fearlesswallet.io",
        "platform":"ios",
        "subject":null,
        "namespace":null,
        "userHandle":null,
        "expiresAt":1120}
        """
        return Data(json.utf8)
    }

    private func sessionBody() -> Data {
        let json = """
        {"sessionToken":"session.\(b64(Data(repeating: 9, count: 32)))",
        "subject":"\(ownerSubject)",
        "namespace":"\(backupNamespace)",
        "generation":0,
        "platform":"ios",
        "expiresAt":1600}
        """
        return Data(json.utf8)
    }

    private func b64(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func assertAuthenticationFailure(
        _ work: () async throws -> Void
    ) async {
        do {
            try await work()
            XCTFail("Untrusted owner session was accepted")
        } catch {
            XCTAssertTrue(error is PasskeyBackupOwnerAuthenticationError)
        }
    }
}

private final class OwnerAuthenticationTransportFixture: PasskeyBackupHTTPTransport {
    var requests: [PasskeyBackupHTTPRequest] = []
    var responses: [PasskeyBackupHTTPResponse] = []

    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }
}

@available(iOS 18.0, *)
@MainActor
private final class OwnerAuthenticationExecutorFixture: PasskeyBackupOwnerAuthenticationExecutor {
    var calls = 0
    let assertion: PasskeyBackupOwnerPublicAssertion

    init(assertion: PasskeyBackupOwnerPublicAssertion) {
        self.assertion = assertion
    }

    func perform(challenge _: PasskeyOwnerAuthChallenge) async throws
        -> PasskeyBackupOwnerPublicAssertion {
        calls += 1
        return assertion
    }
}
