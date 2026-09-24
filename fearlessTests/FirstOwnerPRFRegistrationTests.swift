import AuthenticationServices
import CryptoKit
@testable import fearless
import XCTest

@available(iOS 18.0, *)
@MainActor
final class FirstOwnerPRFRegistrationTests: XCTestCase {
    private let endpoint = URL(string: "https://backup.fearlesswallet.io")!
    private let now: Int64 = 1000

    @available(iOS 18.0, *)
    func testNativeFirstOwnerRequestUsesOwnerChallengeAndLocalPRFSalt() throws {
        let challenge = try challenge()
        let salt = Data(repeating: 0x55, count: 32)
        let context = try PasskeyFirstOwnerPRFRequestContext(challenge: challenge, prfSalt: salt)
        let request = PasskeyFirstOwnerPRFRequestFactory.registration(context: context)
        XCTAssertEqual(request.relyingPartyIdentifier, "fearlesswallet.io")
        XCTAssertEqual(request.challenge, challenge.challenge)
        XCTAssertEqual(request.userID, challenge.userHandle)
        XCTAssertEqual(request.userVerificationPreference, .required)
        XCTAssertEqual(request.attestationPreference, .none)
        XCTAssertEqual(request.prf?.inputValues?.saltInput1, salt)
        XCTAssertNil(request.prf?.inputValues?.saltInput2)
        XCTAssertThrowsError(try PasskeyFirstOwnerPRFRequestContext(challenge: challenge, prfSalt: Data()))
        XCTAssertEqual(String(reflecting: context), "PasskeyFirstOwnerPRFRequestContext(<redacted>)")
    }

    @available(iOS 18.0, *)
    func testNativeFirstOwnerRequiresPRFAndKeepsItOutOfPublicRegistration() throws {
        let context = try PasskeyFirstOwnerPRFRequestContext(
            challenge: challenge(), prfSalt: Data(repeating: 0x55, count: 32)
        )
        let publicRegistration = try registration()
        let secret = Data(repeating: 0x66, count: 32)
        let unavailable: [ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?] = [
            nil, .unsupported, .supported
        ]
        for output in unavailable {
            XCTAssertThrowsError(try PasskeyFirstOwnerPRFCeremonyResult.registration(
                context: context, credentialID: publicRegistration.credentialID,
                clientDataJSON: publicRegistration.clientDataJSON,
                attestationObject: publicRegistration.attestationObject, prf: output
            )) { XCTAssertEqual($0 as? PasskeyBackupPRFError, .missingOutput) }
        }
        let key = SymmetricKey(data: secret)
        XCTAssertThrowsError(try PasskeyFirstOwnerPRFCeremonyResult.registration(
            context: context, credentialID: publicRegistration.credentialID,
            clientDataJSON: publicRegistration.clientDataJSON,
            attestationObject: publicRegistration.attestationObject,
            prf: .init(first: key, second: key)
        ))
        let result = try nativeRegistration(context: context, output: secret)
        let wire = try JSONSerialization.data(withJSONObject: result.registration.credentialObject())
        let text = try XCTUnwrap(String(data: wire, encoding: .utf8))
        XCTAssertFalse(text.contains("prf"))
        XCTAssertFalse(text.contains(secret.base64EncodedString()))
        XCTAssertEqual(String(reflecting: result), "PasskeyFirstOwnerPRFCeremonyResult(<redacted>)")
        XCTAssertEqual(Mirror(reflecting: result).children.count, 0)
    }

    @available(iOS 18.0, *)
    func testNativeFirstOwnerCompletionReleasesLocalPRFOnlyAfterExactServerCommit() async throws {
        let challenge = try challenge()
        let context = try PasskeyFirstOwnerPRFRequestContext(
            challenge: challenge, prfSalt: Data(repeating: 0x55, count: 32)
        )
        let result = try nativeRegistration(context: context)
        let transport = BootstrapTransportFixture()
        transport.responses = [.init(statusCode: 200, body: sessionBody())]
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport,
            isReleaseEnabled: true, nowUnixSeconds: { self.now }
        )
        let verified = try await result.complete(
            challenge: challenge, expectedIdentity: expectedIdentity(),
            signer: BootstrapSignerFixture(), attestor: BootstrapAttestorFixture(), using: source
        )
        XCTAssertEqual(verified.session.ownerSubject, challenge.ownerSubject)
        XCTAssertEqual(verified.credentialID, result.registration.credentialID)
        XCTAssertEqual(verified.prfSalt, context.prfSalt)
        XCTAssertEqual(try verified.withOutput { $0 }, Data(repeating: 0x66, count: 32))
        XCTAssertThrowsError(try verified.withOutput { $0 })
        XCTAssertEqual(String(reflecting: verified), "PasskeyFirstOwnerVerifiedLocalPRF(<redacted>)")
        XCTAssertEqual(transport.requests.count, 1)
        let body = try XCTUnwrap(transport.requests[0].body)
        XCTAssertFalse(try XCTUnwrap(String(data: body, encoding: .utf8)).contains("prf"))
        do {
            _ = try await result.complete(
                challenge: challenge, expectedIdentity: expectedIdentity(),
                signer: BootstrapSignerFixture(), attestor: BootstrapAttestorFixture(), using: source
            )
            XCTFail("Repeated completion accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        XCTAssertEqual(transport.requests.count, 1)
    }

    @available(iOS 18.0, *)
    func testNativeFirstOwnerRejectsSubstitutedChallengeBeforeSigning() async throws {
        let original = try challenge()
        let context = try PasskeyFirstOwnerPRFRequestContext(
            challenge: original, prfSalt: Data(repeating: 0x55, count: 32)
        )
        let result = try nativeRegistration(context: context)
        let wrong = try PasskeyBackupFirstOwnerChallenge(
            ceremonyID: original.ceremonyID, challenge: original.challenge,
            ownerSubject: original.ownerSubject, backupNamespace: original.backupNamespace,
            userHandle: Data(repeating: 0x99, count: 32), expiresAtUnixSeconds: original.expiresAtUnixSeconds
        )
        let transport = BootstrapTransportFixture()
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport,
            isReleaseEnabled: true, nowUnixSeconds: { self.now }
        )
        let signer = BootstrapSignerFixture()
        do {
            _ = try await result.complete(
                challenge: wrong, expectedIdentity: expectedIdentity(),
                signer: signer, attestor: BootstrapAttestorFixture(), using: source
            )
            XCTFail("Changed challenge accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupFirstOwnerBootstrapError, .invalidRegistration) }
        XCTAssertEqual(signer.calls, 0)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testNativeFirstOwnerUnknownCommitConsumesCeremonyWithoutReleasingPRF() async throws {
        let challenge = try challenge()
        let result = try nativeRegistration(context: PasskeyFirstOwnerPRFRequestContext(
            challenge: challenge, prfSalt: Data(repeating: 0x55, count: 32)
        ))
        let transport = BootstrapTransportFixture()
        let source = try HTTPPasskeyOwnerBootstrapSource(
            baseURL: endpoint, transport: transport,
            isReleaseEnabled: true, nowUnixSeconds: { self.now }
        )
        do {
            _ = try await result.complete(
                challenge: challenge, expectedIdentity: expectedIdentity(),
                signer: BootstrapSignerFixture(), attestor: BootstrapAttestorFixture(), using: source
            )
            XCTFail("Unknown server outcome released PRF")
        } catch { XCTAssertEqual(error as? PasskeyBackupFirstOwnerBootstrapError, .completionOutcomeUnknown) }
        do {
            _ = try await result.complete(
                challenge: challenge, expectedIdentity: expectedIdentity(),
                signer: BootstrapSignerFixture(), attestor: BootstrapAttestorFixture(), using: source
            )
            XCTFail("Unknown ceremony was retried")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        XCTAssertEqual(transport.requests.count, 1)
    }

    @available(iOS 18.0, *)
    func testNativeFirstOwnerExecutorIsDisabledBeforePresenting() async throws {
        var presentations = 0
        let executor = ASFirstOwnerPRFExecutor { _, _, _ in
            presentations += 1
            return BootstrapNativeSession()
        }
        do {
            _ = try await executor.performRegistration(
                challenge: challenge(), prfSalt: Data(repeating: 0x55, count: 32)
            )
            XCTFail("Compiled-off owner registration accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled) }
        XCTAssertEqual(presentations, 0)
    }

    @available(iOS 18.0, *)
    func testNativeFirstOwnerExecutorPresentsExactRequestAndReturnsTypedResult() async throws {
        let challenge = try challenge()
        let salt = Data(repeating: 0x55, count: 32)
        let expected = try nativeRegistration(context: PasskeyFirstOwnerPRFRequestContext(
            challenge: challenge, prfSalt: salt
        ))
        let executor = ASFirstOwnerPRFExecutor(
            isReleaseEnabled: true,
            nowUnixSeconds: { self.now },
            sessionFactory: { request, context, completion in
                XCTAssertEqual(request.challenge, challenge.challenge)
                XCTAssertEqual(request.userID, challenge.userHandle)
                XCTAssertEqual(request.prf?.inputValues?.saltInput1, salt)
                return BootstrapNativeSession {
                    XCTAssertEqual(context.challenge.ceremonyID, challenge.ceremonyID)
                    completion(.success(expected))
                }
            }
        )
        let result = try await executor.performRegistration(challenge: challenge, prfSalt: salt)
        XCTAssertEqual(result.context.challenge.ceremonyID, challenge.ceremonyID)
        XCTAssertEqual(result.registration.credentialID, try registration().credentialID)
    }

    func testNativeFirstOwnerExecutorRejectsCallbackWithDifferentPRFSalt() async throws {
        let challenge = try challenge()
        let requestedSalt = Data(repeating: 0x55, count: 32)
        let substituted = try nativeRegistration(context: PasskeyFirstOwnerPRFRequestContext(
            challenge: challenge, prfSalt: Data(repeating: 0x99, count: 32)
        ))
        let executor = ASFirstOwnerPRFExecutor(
            isReleaseEnabled: true,
            nowUnixSeconds: { self.now },
            sessionFactory: { _, _, completion in
                BootstrapNativeSession { completion(.success(substituted)) }
            }
        )
        do {
            _ = try await executor.performRegistration(challenge: challenge, prfSalt: requestedSalt)
            XCTFail("Substituted PRF salt accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidInput) }
    }

    func testNativeFirstOwnerExecutorCancellationCannotSettleNextCeremony() async throws {
        var sessions: [BootstrapNativeSession] = []
        var completions: [ASFirstOwnerPRFExecutor.Completion] = []
        let started = expectation(description: "first started")
        let restarted = expectation(description: "second started")
        let executor = ASFirstOwnerPRFExecutor(
            isReleaseEnabled: true,
            nowUnixSeconds: { self.now },
            sessionFactory: { _, _, completion in
                let session = BootstrapNativeSession {
                    if sessions.count == 1 {
                        started.fulfill()
                    } else {
                        restarted.fulfill()
                    }
                }
                sessions.append(session)
                completions.append(completion)
                return session
            }
        )
        let challenge = try challenge()
        let salt = Data(repeating: 0x55, count: 32)
        let first = Task { try await executor.performRegistration(challenge: challenge, prfSalt: salt) }
        await fulfillment(of: [started], timeout: 2)
        do {
            _ = try await executor.performRegistration(challenge: challenge, prfSalt: salt)
            XCTFail("Concurrent ceremony accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupError, .ceremonyInProgress) }
        first.cancel()
        do { _ = try await first.value; XCTFail("Cancelled ceremony accepted") } catch {}
        XCTAssertEqual(sessions[0].cancellations, 1)
        let second = Task { try await executor.performRegistration(challenge: challenge, prfSalt: salt) }
        await fulfillment(of: [restarted], timeout: 2)
        try completions[0](.success(nativeRegistration(context: PasskeyFirstOwnerPRFRequestContext(
            challenge: challenge, prfSalt: salt
        ))))
        completions[1](.failure(PasskeyBackupPRFError.ceremonyFailed))
        do {
            _ = try await second.value
            XCTFail("Stale completion settled next ceremony")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .ceremonyFailed) }
    }
}

@available(iOS 18.0, *)
private extension FirstOwnerPRFRegistrationTests {
    func challenge() throws -> PasskeyBackupFirstOwnerChallenge {
        try PasskeyBackupFirstOwnerChallenge(
            ceremonyID: "ceremony." + b64(Data(repeating: 6, count: 32)),
            challenge: Data(repeating: 7, count: 32),
            ownerSubject: "owner:" + b64(Data(repeating: 1, count: 32)),
            backupNamespace: "backup:" + b64(Data(repeating: 2, count: 32)),
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

    func expectedIdentity() throws -> PasskeyBackupExpectedWalletIdentity {
        try PasskeyBackupExpectedWalletIdentity(
            storageKey: "storage.wallet.1", walletId: "wallet.1",
            publicIdentitySha256: String(repeating: "a", count: 64)
        )
    }

    func sessionBody() -> Data {
        let owner = "owner:" + b64(Data(repeating: 1, count: 32))
        let namespace = "backup:" + b64(Data(repeating: 2, count: 32))
        return Data("""
        {"sessionToken":"session.\(b64(Data(repeating: 9, count: 32)))","subject":"\(owner)",
        "namespace":"\(namespace)","generation":0,"platform":"ios","expiresAt":1600}
        """.utf8)
    }

    func b64(_ bytes: Data) -> String {
        PasskeyBackupServerAttestationNonce.base64URL(bytes)
    }

    @available(iOS 18.0, *)
    func nativeRegistration(
        context: PasskeyFirstOwnerPRFRequestContext,
        output: Data = Data(repeating: 0x66, count: 32)
    ) throws -> PasskeyFirstOwnerPRFCeremonyResult {
        let registration = try registration()
        return try PasskeyFirstOwnerPRFCeremonyResult.registration(
            context: context, credentialID: registration.credentialID,
            clientDataJSON: registration.clientDataJSON,
            attestationObject: registration.attestationObject,
            prf: .init(first: SymmetricKey(data: output), second: nil)
        )
    }
}

@available(iOS 18.0, *)
@MainActor
private final class BootstrapNativeSession: PasskeyBackupPRFAuthorizationSession {
    private let onStart: () -> Void
    private(set) var cancellations = 0

    init(onStart: @escaping () -> Void = {}) {
        self.onStart = onStart
    }

    func start() {
        onStart()
    }

    func cancel() {
        cancellations += 1
    }
}
