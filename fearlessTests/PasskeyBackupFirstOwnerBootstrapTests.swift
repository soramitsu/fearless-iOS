import CryptoKit
@testable import fearless
import XCTest

@MainActor
final class PasskeyBackupFirstOwnerBootstrapTests: XCTestCase {
    private let endpoint = URL(string: "https://backup.fearlesswallet.io")!
    private let now: Int64 = 1000

    func testWalletMessageAndAttestationNonceMatchOwnerAuthorityVectors() throws {
        let message = try PasskeyBackupFirstOwnerProofFormat.walletMessage(
            challenge: challenge(), registration: registration()
        )
        XCTAssertEqual(message.count, 328)
        XCTAssertEqual(
            hex(Data(SHA256.hash(data: message))),
            "c88efd4e55d72058e5722044c4021c53b6298c33d86e7dcb9654df490bc00b80"
        )
        XCTAssertEqual(
            try hex(registration().commitmentSHA256()),
            "d72abf97f9f58a8ebf7511f6a64c51666c1cd9fb68e128f40d51b84f03b2cf00"
        )
        let proof = try PasskeyBackupFirstOwnerWalletProof(
            scheme: .ed25519,
            publicKey: PasskeyBackupContract.decodeBase64URL(
                "_RckOFqgx1tk-3jNYC-h2ZH96_drE8WO1wLqyDXp9hg"
            ),
            signature: PasskeyBackupContract.decodeBase64URL(
                "zNVHBEOp3UJFzPruLzjtRJbGYRVlq3bV9o1OzrBhzQpi7XthCX2Qf76xmzTNjVLIrSPVOUpBGjRmOd31mLrcDw"
            )
        )
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: proof.publicKey)
        XCTAssertTrue(publicKey.isValidSignature(proof.signature, for: message))
        XCTAssertEqual(
            PasskeyBackupFirstOwnerProofFormat.appAttestationNonce(message: message, proof: proof),
            "Iz4cYbaBAGnIT-VUoHJuwDl33KZ6PuuXYyx7V-yUKL4"
        )
        XCTAssertEqual(String(reflecting: proof), "PasskeyBackupFirstOwnerWalletProof(<redacted>)")
        XCTAssertEqual(try Mirror(reflecting: registration()).children.count, 0)
    }

    func testDisabledSourceDoesNotIssueChallengeOrSignWallet() async throws {
        let transport = BootstrapTransportFixture()
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport
        )
        do {
            _ = try await source.begin()
            XCTFail("Compiled-off owner bootstrap was accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled) }
        let signer = BootstrapSignerFixture()
        let attestor = BootstrapAttestorFixture()
        do {
            _ = try await source.complete(
                challenge: challenge(), registration: registration(), expectedIdentity: expectedIdentity(),
                signer: signer, attestor: attestor
            )
            XCTFail("Compiled-off owner completion was accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled) }
        XCTAssertTrue(transport.requests.isEmpty)
        XCTAssertEqual(signer.calls, 0)
        XCTAssertEqual(attestor.calls, 0)
    }

    func testBootstrapSendsOnlyPublicProofAndAttestationAndReturnsBoundSession() async throws {
        let transport = BootstrapTransportFixture()
        transport.responses = [
            .init(statusCode: 200, body: challengeBody()),
            .init(statusCode: 200, body: sessionBody())
        ]
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport,
            isReleaseEnabled: true, nowUnixSeconds: { self.now }
        )
        let signer = BootstrapSignerFixture()
        let attestor = BootstrapAttestorFixture()
        let issued = try await source.begin()
        let session = try await source.complete(
            challenge: issued, registration: registration(), expectedIdentity: expectedIdentity(),
            signer: signer, attestor: attestor
        )
        XCTAssertEqual(session.ownerSubject, issued.ownerSubject)
        XCTAssertEqual(session.backupNamespace, issued.backupNamespace)
        XCTAssertEqual(signer.calls, 1)
        XCTAssertEqual(signer.verifyCalls, 1)
        let liveProof = try XCTUnwrap(signer.lastProof)
        let liveMessage = try XCTUnwrap(signer.lastMessage)
        XCTAssertEqual(
            attestor.nonce,
            PasskeyBackupFirstOwnerProofFormat.appAttestationNonce(message: liveMessage, proof: liveProof)
        )
        XCTAssertEqual(transport.requests.map(\.url.path), [
            "/api/passkey-backup/v1/owner/bootstrap/challenge",
            "/api/passkey-backup/v1/owner/bootstrap/complete"
        ])
        XCTAssertEqual(transport.requests[0].body, Data(#"{"schemaVersion":1,"platform":"ios"}"#.utf8))
        XCTAssertNil(transport.requests[0].headers["Authorization"])
        XCTAssertNil(transport.requests[1].headers["Authorization"])
        let complete = try XCTUnwrap(transport.requests[1].body)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: complete) as? [String: Any])
        XCTAssertEqual(Set(object.keys), [
            "schemaVersion", "ceremonyId", "credential", "walletProof", "appAttestation"
        ])
        let credential = try XCTUnwrap(object["credential"] as? [String: Any])
        let extensions = try XCTUnwrap(credential["clientExtensionResults"] as? [String: Any])
        XCTAssertTrue(extensions.isEmpty)
        let proof = try XCTUnwrap(object["walletProof"] as? [String: Any])
        XCTAssertEqual(Set(proof.keys), ["scheme", "publicKey", "signature"])
        let app = try XCTUnwrap(object["appAttestation"] as? [String: Any])
        XCTAssertEqual(Set(app.keys), ["kind", "keyId", "attestationObject"])
        let wire = try XCTUnwrap(String(data: complete, encoding: .utf8))
        XCTAssertFalse(wire.localizedCaseInsensitiveContains("prf"))
        XCTAssertFalse(wire.localizedCaseInsensitiveContains("backupkey"))
        XCTAssertFalse(wire.contains(Data(repeating: 9, count: 32).base64EncodedString()))
    }

    func testSubstitutedRegistrationFailsBeforeWalletAuthorization() async throws {
        let transport = BootstrapTransportFixture()
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport,
            isReleaseEnabled: true, nowUnixSeconds: { self.now }
        )
        let signer = BootstrapSignerFixture()
        let attestor = BootstrapAttestorFixture()
        let wrongClientData = "{\"type\":\"webauthn.create\",\"challenge\":\"wrong\"," +
            "\"origin\":\"https://fearlesswallet.io\"}"
        let wrong = try PasskeyFirstOwnerRegistration(
            credentialID: Data(repeating: 3, count: 32),
            clientDataJSON: Data(wrongClientData.utf8),
            attestationObject: Data(repeating: 4, count: 32)
        )
        do {
            _ = try await source.complete(
                challenge: challenge(), registration: wrong, expectedIdentity: expectedIdentity(),
                signer: signer, attestor: attestor
            )
            XCTFail("Substituted registration was signed")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupFirstOwnerBootstrapError, .invalidRegistration)
        }
        XCTAssertEqual(signer.calls, 0)
        XCTAssertEqual(attestor.calls, 0)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testWalletIdentityOrKeyChangeAfterAttestationStopsBeforeOwnerCommit() async throws {
        for change in 0 ..< 3 {
            let transport = BootstrapTransportFixture()
            let source = try HTTPPasskeyOwnerBootstrapSource(
                baseURL: endpoint, transport: transport,
                isReleaseEnabled: true, nowUnixSeconds: { self.now }
            )
            let signer = BootstrapSignerFixture()
            if change == 0 {
                signer.observedAfterUI = try PasskeyBackupExpectedWalletIdentity(
                    storageKey: "storage.wallet.1", walletId: "wallet.2",
                    publicIdentitySha256: String(repeating: "a", count: 64)
                )
            } else if change == 1 {
                signer.authorizedKeyAfterUI = Data(repeating: 0x55, count: 32)
            } else {
                signer.decryptionVerified = false
            }
            let attestor = BootstrapAttestorFixture()
            do {
                _ = try await source.complete(
                    challenge: challenge(), registration: registration(), expectedIdentity: expectedIdentity(),
                    signer: signer, attestor: attestor
                )
                XCTFail("Changed selected wallet or key was accepted")
            } catch { XCTAssertEqual(error as? PasskeyBackupFirstOwnerBootstrapError, .invalidWalletProof) }
            XCTAssertEqual(signer.calls, 1)
            XCTAssertEqual(signer.verifyCalls, change == 2 ? 0 : 1)
            XCTAssertEqual(attestor.calls, change == 2 ? 0 : 1)
            XCTAssertTrue(transport.requests.isEmpty)
        }
    }

    func testRejectsDuplicateChallengeAndMismatchedOwnerSession() async throws {
        let original = try XCTUnwrap(String(data: challengeBody(), encoding: .utf8))
        let cases = [
            original.replacingOccurrences(of: #""subject":"#, with: #""subject":"bad","subject":"#),
            original.replacingOccurrences(of: #""kind":"bootstrap""#, with: #""kind":"authentication""#),
            original.replacingOccurrences(of: #""platform":"ios""#, with: #""platform":"android""#),
            original.replacingOccurrences(of: #""expiresAt":1120"#, with: #""expiresAt":1000"#),
            original.replacingOccurrences(of: #""userHandle":"#, with: #""userHandle":"bad","userHandle":"#)
        ]
        for body in cases {
            let transport = BootstrapTransportFixture()
            transport.responses = [.init(statusCode: 200, body: Data(body.utf8))]
            let source = try HTTPPasskeyOwnerBootstrapSource(
                baseURL: endpoint, transport: transport,
                isReleaseEnabled: true, nowUnixSeconds: { self.now }
            )
            do {
                _ = try await source.begin()
                XCTFail("Untrusted challenge was accepted")
            } catch { XCTAssertTrue(error is PasskeyBackupFirstOwnerBootstrapError) }
        }

        let transport = BootstrapTransportFixture()
        let mismatched = try XCTUnwrap(String(data: sessionBody(), encoding: .utf8))
            .replacingOccurrences(of: ownerSubject, with: "owner:" + b64(Data(repeating: 10, count: 32)))
        transport.responses = [.init(statusCode: 200, body: Data(mismatched.utf8))]
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport,
            isReleaseEnabled: true, nowUnixSeconds: { self.now }
        )
        do {
            _ = try await source.complete(
                challenge: challenge(), registration: registration(),
                expectedIdentity: expectedIdentity(),
                signer: BootstrapSignerFixture(), attestor: BootstrapAttestorFixture()
            )
            XCTFail("Substituted owner session was accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupFirstOwnerBootstrapError, .completionOutcomeUnknown) }
    }

    func testUncertainCompletionIsNotTreatedAsSuccess() async throws {
        let transport = BootstrapTransportFixture()
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport,
            isReleaseEnabled: true, nowUnixSeconds: { self.now }
        )
        do {
            _ = try await source.complete(
                challenge: challenge(), registration: registration(),
                expectedIdentity: expectedIdentity(),
                signer: BootstrapSignerFixture(), attestor: BootstrapAttestorFixture()
            )
            XCTFail("Unknown commit outcome was accepted")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupFirstOwnerBootstrapError, .completionOutcomeUnknown)
        }
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testPostDispatchHTTPAndTruncatedResponsesRequireAuthenticationReconciliation() async throws {
        let responses: [PasskeyBackupHTTPResponse] = [
            .init(statusCode: 409, body: Data(#"{"error":"owner_already_exists"}"#.utf8)),
            .init(statusCode: 200, body: Data(#"{"sessionToken":"session."}"#.utf8)),
            .init(statusCode: 200, body: Data(repeating: 65, count: 8193))
        ]
        for response in responses {
            let transport = BootstrapTransportFixture()
            transport.responses = [response]
            let source = try HTTPPasskeyOwnerBootstrapSource(
                baseURL: endpoint, transport: transport,
                isReleaseEnabled: true, nowUnixSeconds: { self.now }
            )
            do {
                _ = try await source.complete(
                    challenge: challenge(), registration: registration(),
                    expectedIdentity: expectedIdentity(),
                    signer: BootstrapSignerFixture(), attestor: BootstrapAttestorFixture()
                )
                XCTFail("Ambiguous owner completion was accepted")
            } catch {
                XCTAssertEqual(error as? PasskeyBackupFirstOwnerBootstrapError, .completionOutcomeUnknown)
            }
            XCTAssertEqual(transport.requests.count, 1)
        }
    }
}

private extension PasskeyBackupFirstOwnerBootstrapTests {
    var ceremonyID: String {
        "ceremony." + b64(Data(repeating: 6, count: 32))
    }

    var ownerSubject: String {
        "owner:" + b64(Data(repeating: 1, count: 32))
    }

    var backupNamespace: String {
        "backup:" + b64(Data(repeating: 2, count: 32))
    }

    func expectedIdentity() throws -> PasskeyBackupExpectedWalletIdentity {
        try PasskeyBackupExpectedWalletIdentity(
            storageKey: "storage.wallet.1", walletId: "wallet.1",
            publicIdentitySha256: String(repeating: "a", count: 64)
        )
    }

    func challenge() throws -> PasskeyBackupFirstOwnerChallenge {
        try PasskeyBackupFirstOwnerChallenge(
            ceremonyID: ceremonyID, challenge: Data(repeating: 7, count: 32),
            ownerSubject: ownerSubject, backupNamespace: backupNamespace,
            userHandle: Data(repeating: 8, count: 32), expiresAtUnixSeconds: 1120
        )
    }

    func registration() throws -> PasskeyFirstOwnerRegistration {
        let json = "{\"type\":\"webauthn.create\",\"challenge\":\"" +
            b64(Data(repeating: 7, count: 32)) +
            "\",\"origin\":\"https://fearlesswallet.io\",\"crossOrigin\":false}"
        return try PasskeyFirstOwnerRegistration(
            credentialID: Data(repeating: 3, count: 32),
            clientDataJSON: Data(json.utf8), attestationObject: Data(repeating: 4, count: 32)
        )
    }

    func challengeBody() -> Data {
        Data("""
        {"ceremonyId":"\(ceremonyID)","kind":"bootstrap","challenge":"\(b64(Data(repeating: 7, count: 32)))",
        "rpId":"fearlesswallet.io","platform":"ios","subject":"\(ownerSubject)",
        "namespace":"\(backupNamespace)","userHandle":"\(b64(Data(repeating: 8, count: 32)))","expiresAt":1120}
        """.utf8)
    }

    func sessionBody() -> Data {
        Data("""
        {"sessionToken":"session.\(b64(Data(repeating: 9, count: 32)))","subject":"\(ownerSubject)",
        "namespace":"\(backupNamespace)","generation":0,"platform":"ios","expiresAt":1600}
        """.utf8)
    }

    func b64(_ bytes: Data) -> String {
        PasskeyBackupServerAttestationNonce.base64URL(bytes)
    }

    func hex(_ bytes: Data) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }
}

final class BootstrapTransportFixture: PasskeyBackupHTTPTransport {
    var requests: [PasskeyBackupHTTPRequest] = []
    var responses: [PasskeyBackupHTTPResponse] = []

    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.badServerResponse) }
        return responses.removeFirst()
    }
}

@MainActor
final class BootstrapSignerFixture: PasskeyOwnerWalletSigner {
    var calls = 0
    var verifyCalls = 0
    var observedAfterUI: PasskeyBackupExpectedWalletIdentity?
    var authorizedKeyAfterUI: Data?
    var decryptionVerified = true
    var lastProof: PasskeyBackupFirstOwnerWalletProof?
    var lastMessage: Data?

    func authorizeAndSign(
        _ message: Data, expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyOwnerWalletSignedProof {
        calls += 1
        let key = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 9, count: 32))
        let proof = try PasskeyBackupFirstOwnerWalletProof(
            scheme: .ed25519, publicKey: key.publicKey.rawRepresentation,
            signature: key.signature(for: message)
        )
        lastProof = proof
        lastMessage = message
        return PasskeyOwnerWalletSignedProof(
            proof: proof, evidence: PasskeyOwnerWalletEvidence(
                observedIdentity: expectedIdentity,
                authorizedScheme: .ed25519,
                authorizedPublicKey: proof.normalizedPublicKey,
                decryptionVerified: decryptionVerified,
                originalKeySigningVerified: true, originalKeyExportVerified: true
            )
        )
    }

    func verifyCurrentWallet(
        expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyOwnerWalletEvidence {
        verifyCalls += 1
        return PasskeyOwnerWalletEvidence(
            observedIdentity: observedAfterUI ?? expectedIdentity,
            authorizedScheme: .ed25519,
            authorizedPublicKey: authorizedKeyAfterUI ?? lastProof?.normalizedPublicKey ?? Data(),
            decryptionVerified: decryptionVerified,
            originalKeySigningVerified: true, originalKeyExportVerified: true
        )
    }
}

@MainActor
final class BootstrapAttestorFixture: PasskeyBackupFirstOwnerAppAttestor {
    var calls = 0
    var nonce: String?

    func attest(challenge: PasskeyBackupAppAttestChallenge) async throws -> PasskeyBackupAppAttestTransport {
        calls += 1
        nonce = PasskeyBackupServerAttestationNonce.base64URL(challenge.nonce.bytes)
        return try PasskeyBackupAppAttestTransport(
            appleKeyID: Data(repeating: 5, count: 32).base64EncodedString(),
            attestation: Data(repeating: 6, count: 64)
        )
    }
}
