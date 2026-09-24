import DeviceCheck
@testable import fearless
import Security
import XCTest

@MainActor
final class PasskeyBackupAppAttestRetryTests: XCTestCase {
    private let ed25519Nonce = "Dr_VXH8Ai6s3QRzd55kKMpjlZqONU85h3ibeqqto63E"
    private let appleKeyID = Data((0 ..< 32).map(UInt8.init)).base64EncodedString()
    private let attestation = Data(repeating: 0xA5, count: 64)
    private let pendingStore = FixtureStore()

    func testServerUnavailableReusesExactPendingKeyAndHashAfterBootstrapRecreation() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let challenge = try PasskeyBackupAppAttestChallenge(
            serverNonce: ed25519Nonce, ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:0123456789abcdef", expiresAt: now.addingTimeInterval(90)
        )
        let gateway = FixtureGateway()
        let generated = expectation(description: "first key generated")
        let firstAttest = expectation(description: "first attest started")
        gateway.onGenerate = { generated.fulfill() }
        gateway.onAttest = { firstAttest.fulfill() }
        let firstBootstrap = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true, now: { now }
        )
        let first = Task { try await firstBootstrap.attest(challenge: challenge) }
        await fulfillment(of: [generated], timeout: 2)
        gateway.generateCompletion?(.success(appleKeyID))
        await fulfillment(of: [firstAttest], timeout: 2)
        XCTAssertEqual(pendingStore.saveCount, 1)
        gateway.attestCompletion?(.failure(PasskeyBackupAppAttestError.serverUnavailable))
        do {
            _ = try await first.value
            XCTFail("Expected transient failure")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .serverUnavailable) }
        XCTAssertEqual(pendingStore.pending?.appleKeyID, appleKeyID)
        XCTAssertEqual(pendingStore.clearCount, 0)

        let secondAttest = expectation(description: "same key retried")
        gateway.onGenerate = { XCTFail("Transient retry must not generate a new Apple key") }
        gateway.onAttest = { secondAttest.fulfill() }
        let recreated = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true, now: { now }
        )
        let second = Task { try await recreated.attest(challenge: challenge) }
        await fulfillment(of: [secondAttest], timeout: 2)
        XCTAssertEqual(gateway.generateCount, 1)
        XCTAssertEqual(gateway.attestedKeyID, appleKeyID)
        XCTAssertEqual(gateway.clientDataHash, challenge.nonce.clientDataHash)
        gateway.attestCompletion?(.success(attestation))
        let transport = try await second.value
        XCTAssertEqual(transport.kind, "app-attest")
        XCTAssertNil(pendingStore.pending)
        XCTAssertEqual(pendingStore.clearCount, 1)
    }

    func testPendingKeyCannotCrossOwnerCeremonyOrExpiry() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let original = try PasskeyBackupAppAttestChallenge(
            serverNonce: ed25519Nonce, ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:0123456789abcdef", expiresAt: now.addingTimeInterval(90)
        )
        let otherOwner = try PasskeyBackupAppAttestChallenge(
            serverNonce: ed25519Nonce, ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:fedcba9876543210", expiresAt: now.addingTimeInterval(90)
        )
        pendingStore.pending = try PasskeyBackupPendingAppAttestation(
            appleKeyID: appleKeyID, challenge: original
        )
        let gateway = FixtureGateway()
        let bootstrap = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true, now: { now }
        )
        do {
            _ = try await bootstrap.attest(challenge: otherOwner)
            XCTFail("Expected owner mismatch")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .pendingChallengeMismatch) }
        XCTAssertEqual(gateway.generateCount, 0)
        XCTAssertEqual(gateway.attestCount, 0)
        XCTAssertEqual(pendingStore.pending?.appleKeyID, appleKeyID)

        let expired = try PasskeyBackupAppAttestChallenge(
            serverNonce: ed25519Nonce, ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:0123456789abcdef", expiresAt: now.addingTimeInterval(-1)
        )
        do {
            _ = try await bootstrap.attest(challenge: expired)
            XCTFail("Expected expiry")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .challengeExpired) }
        XCTAssertEqual(gateway.generateCount, 0)

        pendingStore.pending = try PasskeyBackupPendingAppAttestation(
            appleKeyID: appleKeyID, challenge: expired
        )
        let generated = expectation(description: "new key generated after expiry")
        gateway.onGenerate = { generated.fulfill() }
        let replacement = Task { try await bootstrap.attest(challenge: otherOwner) }
        await fulfillment(of: [generated], timeout: 2)
        XCTAssertNil(pendingStore.pending)
        XCTAssertEqual(pendingStore.clearCount, 1)
        replacement.cancel()
        do {
            _ = try await replacement.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .cancelled) }
    }

    func testNativeServerUnavailableClassificationRequiresAppleDomainAndExactCode() {
        XCTAssertTrue(SystemPasskeyBackupAppAttestGateway.isServerUnavailable(NSError(
            domain: DCErrorDomain, code: DCError.Code.serverUnavailable.rawValue
        )))
        XCTAssertFalse(SystemPasskeyBackupAppAttestGateway.isServerUnavailable(NSError(
            domain: "other", code: DCError.Code.serverUnavailable.rawValue
        )))
        XCTAssertFalse(SystemPasskeyBackupAppAttestGateway.isServerUnavailable(NSError(
            domain: DCErrorDomain, code: DCError.Code.invalidKey.rawValue
        )))
    }

    func testKeychainPendingKeySurvivesStoreRecreationAndClear() throws {
        let service = "jp.co.soramitsu.fearlesswallet.test-app-attest.\(UUID().uuidString)"
        let firstStore = KeychainPendingAppAttestationStore(service: service)
        defer { try? firstStore.clear() }
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "first-owner-bootstrap"
        ] as CFDictionary, &result)
        XCTAssertEqual(status, errSecItemNotFound, "Unexpected unsigned-simulator Keychain status: \(status)")
        XCTAssertNil(try firstStore.load())
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let challenge = try PasskeyBackupAppAttestChallenge(
            serverNonce: ed25519Nonce, ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:0123456789abcdef", expiresAt: now.addingTimeInterval(90)
        )
        try firstStore.save(PasskeyBackupPendingAppAttestation(
            appleKeyID: appleKeyID, challenge: challenge
        ))
        var attributesResult: CFTypeRef?
        let attributesStatus = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: "first-owner-bootstrap",
            kSecReturnAttributes: true
        ] as CFDictionary, &attributesResult)
        XCTAssertEqual(attributesStatus, errSecSuccess)
        let attributes = try XCTUnwrap(attributesResult as? [String: Any])
        XCTAssertEqual(
            attributes[kSecAttrAccessible as String] as? String,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String
        )
        let recreatedStore = KeychainPendingAppAttestationStore(service: service)
        let recovered = try XCTUnwrap(recreatedStore.load())
        XCTAssertEqual(recovered.appleKeyID, appleKeyID)
        XCTAssertTrue(recovered.matches(challenge))
        try recreatedStore.clear()
        XCTAssertNil(try firstStore.load())
    }

    func testKeychainClearFailureWithholdsAttestationTransport() async throws {
        let gateway = FixtureGateway()
        let generated = expectation(description: "key generated")
        let attested = expectation(description: "attest started")
        gateway.onGenerate = { generated.fulfill() }
        gateway.onAttest = { attested.fulfill() }
        pendingStore.failClear = true
        let bootstrap = PasskeyBackupAppAttestBootstrap(
            gateway: gateway, pendingStore: pendingStore, isReleaseEnabled: true
        )
        let challenge = try PasskeyBackupAppAttestChallenge(
            serverNonce: ed25519Nonce, ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:0123456789abcdef",
            expiresAt: Date(timeIntervalSince1970: Double(Int64(Date().timeIntervalSince1970) + 90))
        )
        let task = Task { try await bootstrap.attest(challenge: challenge) }
        await fulfillment(of: [generated], timeout: 2)
        gateway.generateCompletion?(.success(appleKeyID))
        await fulfillment(of: [attested], timeout: 2)
        gateway.attestCompletion?(.success(attestation))
        do {
            _ = try await task.value
            XCTFail("Expected local journal failure")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .storageUnavailable) }
        XCTAssertEqual(pendingStore.pending?.appleKeyID, appleKeyID)
    }

    func testSeparateAdaptersCannotStartConcurrentAppleKeyCeremonies() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let challenge = try PasskeyBackupAppAttestChallenge(
            serverNonce: ed25519Nonce, ceremonyID: "ceremony.0123456789abcdef",
            subject: "owner:0123456789abcdef", expiresAt: now.addingTimeInterval(90)
        )
        let firstGateway = FixtureGateway()
        let secondGateway = FixtureGateway()
        let started = expectation(description: "first key generation started")
        firstGateway.onGenerate = { started.fulfill() }
        let firstAdapter = PasskeyBackupAppAttestBootstrap(
            gateway: firstGateway, pendingStore: pendingStore, isReleaseEnabled: true, now: { now }
        )
        let secondAdapter = PasskeyBackupAppAttestBootstrap(
            gateway: secondGateway, pendingStore: pendingStore, isReleaseEnabled: true, now: { now }
        )
        let first = Task { try await firstAdapter.attest(challenge: challenge) }
        await fulfillment(of: [started], timeout: 2)
        do {
            _ = try await secondAdapter.attest(challenge: challenge)
            XCTFail("Expected one device-local ceremony at a time")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .ceremonyInProgress) }
        XCTAssertEqual(secondGateway.generateCount, 0)
        first.cancel()
        do {
            _ = try await first.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .cancelled) }

        let secondStarted = expectation(description: "second generation started after cancellation")
        secondGateway.onGenerate = { secondStarted.fulfill() }
        let second = Task { try await secondAdapter.attest(challenge: challenge) }
        await fulfillment(of: [secondStarted], timeout: 2)
        second.cancel()
        do {
            _ = try await second.value
            XCTFail("Expected cancellation")
        } catch { XCTAssertEqual(error as? PasskeyBackupAppAttestError, .cancelled) }
    }
}
