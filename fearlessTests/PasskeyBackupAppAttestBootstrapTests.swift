import CryptoKit
import DeviceCheck
@testable import fearless
import XCTest

@MainActor
final class PasskeyBackupAppAttestBootstrapTests: XCTestCase {
    private let ed25519Nonce = "Dr_VXH8Ai6s3QRzd55kKMpjlZqONU85h3ibeqqto63E"
    private let secp256k1Nonce = "9x058rszLaGLNZygww8u8wdT1V91_W9HvLAn_PDMGwY"
    private let appleKeyID = Data((0 ..< 32).map(UInt8.init)).base64EncodedString()
    private let attestation = Data(repeating: 0xA5, count: 64)
    private let pendingStore = FixtureStore()

    func testClientDataHashMatchesServerWalletProofVectors() throws {
        // These are the owner authority's real-signature public Ed25519/secp256k1 vectors.
        let ed25519 = try PasskeyBackupServerAttestationNonce(base64URL: ed25519Nonce)
        let secp = try PasskeyBackupServerAttestationNonce(base64URL: secp256k1Nonce)
        XCTAssertEqual(ed25519.clientDataHash.hex, "9fcb32be940c8732b4894890beeab5292a2f83d41af2fc4ed0acab3e1ab6ea6f")
        XCTAssertEqual(secp.clientDataHash.hex, "e7194ded16d065656af512ad7800f99ed541cccf3e05d612e28d021a022a88ad")
        XCTAssertEqual(String(describing: ed25519), "PasskeyBackupServerAttestationNonce(<redacted>)")
        XCTAssertNotEqual(ed25519.clientDataHash, Data(SHA256.hash(data: Data(ed25519Nonce.utf8))))
    }

    func testRejectsMalformedOrNoncanonicalServerNonce() {
        for value in ["", String(repeating: "A", count: 42), ed25519Nonce + "=", ed25519Nonce + "!",
                      ed25519Nonce.replacingOccurrences(of: "_", with: "/")] {
            XCTAssertThrowsError(try PasskeyBackupServerAttestationNonce(base64URL: value)) {
                XCTAssertEqual($0 as? PasskeyBackupAppAttestError, .invalidServerNonce)
            }
        }
    }

    func testCanonicalizesAppleBase64KeyAndSerializesOnlyServerFields() throws {
        let transport = try PasskeyBackupAppAttestTransport(
            appleKeyID: appleKeyID, attestation: attestation
        )
        XCTAssertEqual(transport.kind, "app-attest")
        XCTAssertEqual(transport.keyId, PasskeyBackupServerAttestationNonce.base64URL(Data((0 ..< 32).map(UInt8.init))))
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: transport.serverAttestationJSON()) as? [String: String]
        )
        XCTAssertEqual(Set(json.keys), ["kind", "keyId", "attestationObject"])
        XCTAssertEqual(json["attestationObject"], PasskeyBackupServerAttestationNonce.base64URL(attestation))
        XCTAssertFalse(String(describing: transport).contains(transport.attestationObject))
        let slashKey = try PasskeyBackupAppAttestTransport(
            appleKeyID: Data(repeating: 0xFF, count: 32).base64EncodedString(), attestation: attestation
        )
        XCTAssertEqual(slashKey.keyId, "__________________________________________8")
        for bad in [appleKeyID.replacingOccurrences(of: "=", with: ""), " " + appleKeyID,
                    Data(repeating: 1, count: 31).base64EncodedString()] {
            XCTAssertThrowsError(try PasskeyBackupAppAttestTransport(
                appleKeyID: bad, attestation: attestation
            )) { XCTAssertEqual($0 as? PasskeyBackupAppAttestError, .invalidKeyID) }
        }
        for count in [0, 31, 32769] {
            XCTAssertThrowsError(try PasskeyBackupAppAttestTransport(
                appleKeyID: appleKeyID, attestation: Data(repeating: 1, count: count)
            )) { XCTAssertEqual($0 as? PasskeyBackupAppAttestError, .invalidAttestation) }
        }
    }

    func testCompiledRecoveryGateStopsBeforeNativeSupportOrKeyGeneration() async {
        let gateway = FixtureGateway()
        let bootstrap = PasskeyBackupAppAttestBootstrap(gateway: gateway, pendingStore: pendingStore)
        do {
            _ = try await bootstrap.attest(serverNonce: ed25519Nonce)
            XCTFail("Expected rejection")
        } catch { XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled) }
        XCTAssertEqual(gateway.supportChecks, 0)
        XCTAssertEqual(gateway.generateCount, 0)
        XCTAssertFalse(PasskeyBackupReleaseConfig.isPasskeyBackupEnabled)
    }

    func testUnsupportedAndInvalidNonceFailBeforeGeneratingKey() async {
        let gateway = FixtureGateway()
        let bootstrap = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true
        )
        do {
            _ = try await bootstrap.attest(serverNonce: "invalid")
            XCTFail("Expected rejection")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .invalidServerNonce) }
        gateway.supported = false
        do {
            _ = try await bootstrap.attest(serverNonce: ed25519Nonce)
            XCTFail("Expected rejection")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .unavailable) }
        XCTAssertEqual(gateway.generateCount, 0)
    }

    func testNativeSequenceUsesExactDecodedNonceHashAndReturnsTypedTransport() async throws {
        let gateway = FixtureGateway()
        let keyStarted = expectation(description: "key generation started")
        let attestStarted = expectation(description: "attestation started")
        gateway.onGenerate = { keyStarted.fulfill() }
        gateway.onAttest = { attestStarted.fulfill() }
        let bootstrap = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true
        )
        let task = Task { try await bootstrap.attest(serverNonce: ed25519Nonce) }
        await fulfillment(of: [keyStarted], timeout: 2)
        XCTAssertNil(gateway.attestCompletion)
        gateway.generateCompletion?(.success(appleKeyID))
        await fulfillment(of: [attestStarted], timeout: 2)
        XCTAssertEqual(gateway.attestedKeyID, appleKeyID)
        XCTAssertEqual(gateway.clientDataHash?.hex, "9fcb32be940c8732b4894890beeab5292a2f83d41af2fc4ed0acab3e1ab6ea6f")
        gateway.attestCompletion?(.success(attestation))
        let result = try await task.value
        XCTAssertEqual(result.keyId, PasskeyBackupServerAttestationNonce.base64URL(Data((0 ..< 32).map(UInt8.init))))
    }

    func testNativeErrorsAndMalformedResultsAreSanitized() async throws {
        let gateway = FixtureGateway()
        let keyStarted = expectation(description: "key generation started")
        gateway.onGenerate = { keyStarted.fulfill() }
        let bootstrap = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true
        )
        let failed = Task { try await bootstrap.attest(serverNonce: ed25519Nonce) }
        await fulfillment(of: [keyStarted], timeout: 2)
        gateway.generateCompletion?(.failure(FixtureError.secret))
        do {
            _ = try await failed.value
            XCTFail("Expected rejection")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupAppAttestError, .nativeFailure)
            XCTAssertFalse(String(describing: error).contains("provider-secret"))
        }

        let malformedStarted = expectation(description: "new key generation started")
        gateway.onGenerate = { malformedStarted.fulfill() }
        let malformed = Task { try await bootstrap.attest(serverNonce: ed25519Nonce) }
        await fulfillment(of: [malformedStarted], timeout: 2)
        gateway.generateCompletion?(.success("bad-key"))
        do {
            _ = try await malformed.value
            XCTFail("Expected rejection")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .invalidKeyID) }
        XCTAssertEqual(gateway.attestCount, 0)

        let anotherKeyStarted = expectation(description: "third key generation started")
        let attestStarted = expectation(description: "third attestation started")
        gateway.onGenerate = { anotherKeyStarted.fulfill() }
        gateway.onAttest = { attestStarted.fulfill() }
        let attestationFailed = Task { try await bootstrap.attest(serverNonce: ed25519Nonce) }
        await fulfillment(of: [anotherKeyStarted], timeout: 2)
        gateway.generateCompletion?(.success(appleKeyID))
        await fulfillment(of: [attestStarted], timeout: 2)
        gateway.attestCompletion?(.failure(FixtureError.secret))
        do {
            _ = try await attestationFailed.value
            XCTFail("Expected native attestation rejection")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupAppAttestError, .nativeFailure)
            XCTAssertFalse(String(describing: error).contains("provider-secret"))
        }
    }

    func testCancellationIgnoresLateCallbackAndCannotSettleNextCeremony() async throws {
        let gateway = FixtureGateway()
        let firstStarted = expectation(description: "first key started")
        gateway.onGenerate = { firstStarted.fulfill() }
        let bootstrap = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true
        )
        let first = Task { try await bootstrap.attest(serverNonce: ed25519Nonce) }
        await fulfillment(of: [firstStarted], timeout: 2)
        let oldCompletion = try XCTUnwrap(gateway.generateCompletion)
        do {
            _ = try await bootstrap.attest(serverNonce: ed25519Nonce)
            XCTFail("Expected rejection")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .ceremonyInProgress) }
        first.cancel()
        do {
            _ = try await first.value
            XCTFail("Expected rejection")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .cancelled) }

        let secondStarted = expectation(description: "second key started")
        let secondAttest = expectation(description: "second attestation started")
        gateway.onGenerate = { secondStarted.fulfill() }
        gateway.onAttest = { secondAttest.fulfill() }
        let second = Task { try await bootstrap.attest(serverNonce: secp256k1Nonce) }
        await fulfillment(of: [secondStarted], timeout: 2)
        oldCompletion(.success(appleKeyID))
        gateway.generateCompletion?(.success(appleKeyID))
        await fulfillment(of: [secondAttest], timeout: 2)
        XCTAssertEqual(gateway.attestCount, 1)
        XCTAssertEqual(gateway.clientDataHash?.hex, "e7194ded16d065656af512ad7800f99ed541cccf3e05d612e28d021a022a88ad")
        gateway.attestCompletion?(.success(attestation))
        let secondResult = try await second.value
        XCTAssertEqual(secondResult.kind, "app-attest")
    }
}

private struct FixtureError: Error, CustomStringConvertible {
    static let secret = FixtureError()
    var description: String {
        "provider-secret"
    }
}

@MainActor
final class FixtureStore: PasskeyBackupPendingAttestationStore {
    var pending: PasskeyBackupPendingAppAttestation?
    var saveCount = 0
    var clearCount = 0
    var failClear = false
    func load() throws -> PasskeyBackupPendingAppAttestation? {
        pending
    }

    func save(_ pending: PasskeyBackupPendingAppAttestation) throws {
        self.pending = pending
        saveCount += 1
    }

    func clear() throws {
        if failClear {
            throw PasskeyBackupAppAttestError.storageUnavailable
        }
        pending = nil
        clearCount += 1
    }
}

@MainActor
final class FixtureGateway: PasskeyBackupAppAttestGateway {
    var supported = true
    var supportChecks = 0
    var generateCount = 0
    var attestCount = 0
    var onGenerate: (() -> Void)?
    var onAttest: (() -> Void)?
    var generateCompletion: ((Result<String, Error>) -> Void)?
    var attestCompletion: ((Result<Data, Error>) -> Void)?
    var attestedKeyID: String?
    var clientDataHash: Data?

    var isSupported: Bool {
        supportChecks += 1
        return supported
    }

    func generateKey(completion: @escaping (Result<String, Error>) -> Void) {
        generateCount += 1
        generateCompletion = completion
        onGenerate?()
    }

    func attestKey(
        _ keyID: String, clientDataHash: Data,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        attestCount += 1
        attestedKeyID = keyID
        self.clientDataHash = clientDataHash
        attestCompletion = completion
        onAttest?()
    }
}

private extension Data {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
private extension PasskeyBackupAppAttestBootstrap {
    func attest(serverNonce: String) async throws -> PasskeyBackupAppAttestTransport {
        let challenge = try PasskeyBackupAppAttestChallenge(
            serverNonce: serverNonce,
            ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:0123456789abcdef",
            expiresAt: Date(timeIntervalSince1970: Double(Int64(Date().timeIntervalSince1970) + 90))
        )
        return try await attest(challenge: challenge)
    }
}
