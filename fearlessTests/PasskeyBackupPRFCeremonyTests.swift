import AuthenticationServices
import CryptoKit
import XCTest
@testable import fearless

@available(iOS 18.0, *)
@MainActor
final class PasskeyBackupPRFCeremonyTests: XCTestCase {
    private let salt = Data(repeating: 0x33, count: 32)
    private let credentialID = Data(repeating: 0x22, count: 32)
    private let secret = Data(repeating: 0x66, count: 32)

    func testRegistrationRequestUsesCallerSaltRequiredUVAndNativePRF() throws {
        let pending = try registration()
        let (request, context) = try PasskeyBackupPRFRequestFactory.registration(pending, prfSalt: salt)
        XCTAssertEqual(request.relyingPartyIdentifier, "fearlesswallet.io")
        XCTAssertEqual(request.challenge, pending.challenge)
        XCTAssertEqual(request.userID, pending.userId)
        XCTAssertEqual(request.displayName, pending.displayName)
        XCTAssertEqual(request.userVerificationPreference, .required)
        XCTAssertEqual(request.attestationPreference, .none)
        XCTAssertEqual(request.prf?.inputValues?.saltInput1, salt)
        XCTAssertNil(request.prf?.inputValues?.saltInput2)
        XCTAssertEqual(context.kind, .registration)
    }

    func testAssertionRequestRestrictsCredentialAndUsesOnlyItsSalt() throws {
        let context = try assertionContext()
        let request = try PasskeyBackupPRFRequestFactory.assertion(context)
        XCTAssertEqual(request.relyingPartyIdentifier, "fearlesswallet.io")
        XCTAssertEqual(request.challenge, context.challenge)
        XCTAssertEqual(request.userVerificationPreference, .required)
        XCTAssertEqual(request.allowedCredentials.map(\.credentialID), [credentialID])
        XCTAssertNil(request.prf?.inputValues)
        XCTAssertEqual(request.prf?.perCredentialInputValues?.count, 1)
        XCTAssertEqual(request.prf?.perCredentialInputValues?[credentialID]?.saltInput1, salt)
        XCTAssertNil(request.prf?.perCredentialInputValues?[credentialID]?.saltInput2)
    }

    func testInvalidSaltCredentialAndWrongRequestKindFailBeforeNativeRequests() throws {
        for count in [0, 31, 33, 64] {
            XCTAssertThrowsError(try PasskeyBackupPRFRequestFactory.registration(
                registration(), prfSalt: Data(repeating: 1, count: count)
            ))
            XCTAssertThrowsError(try PasskeyBackupPRFContext.assertion(
                assertion(), prfSalt: Data(repeating: 1, count: count), credentialID: credentialID
            ))
        }
        for credential in [Data(), Data(repeating: 1, count: 385)] {
            XCTAssertThrowsError(try PasskeyBackupPRFContext.assertion(
                assertion(), prfSalt: salt, credentialID: credential
            ))
        }
        XCTAssertThrowsError(try PasskeyBackupPRFRequestFactory.assertion(
            PasskeyBackupPRFContext.registration(registration(), prfSalt: salt)
        ))
        XCTAssertThrowsError(try PasskeyBackupPRFContext.assertion(
            assertion(directed: false), prfSalt: salt, credentialID: credentialID
        ))
        XCTAssertThrowsError(try PasskeyBackupPRFContext.assertion(
            assertion(), prfSalt: salt, credentialID: Data(repeating: 0x44, count: 32)
        ))
    }

    func testCreationMissingUnsupportedOrSupportOnlyOutputRequiresAssertion() throws {
        let outputs: [ASAuthorizationPublicKeyCredentialPRFRegistrationOutput?] = [nil, .unsupported, .supported]
        for output in outputs {
            let result = try registrationResult(output: output)
            XCTAssertTrue(result.requiresAssertion)
            XCTAssertThrowsError(try PasskeyBackupPRFEnrollmentGate(registration: result).takeVerifiedOutput())
        }
    }

    func testCreationOutputRemainsLocalAndUnverified() throws {
        let result = try registrationResult(output: .init(first: SymmetricKey(data: secret), second: nil))
        XCTAssertFalse(result.requiresAssertion)
        let json = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(result.credentialResponseJSON.utf8))
                as? [String: Any]
        )
        XCTAssertEqual((json["clientExtensionResults"] as? [String: Any])?.count, 0)
        XCTAssertFalse(result.credentialResponseJSON.contains(secret.base64EncodedString()))
        XCTAssertFalse(result.credentialResponseJSON.contains("prf"))
        XCTAssertEqual(String(reflecting: result), "PasskeyBackupPRFCeremonyResult(<redacted>)")
        XCTAssertEqual(Mirror(reflecting: result).children.count, 0)
        XCTAssertEqual(Mirror(reflecting: result.context).children.count, 0)
        XCTAssertThrowsError(try PasskeyBackupPRFEnrollmentGate(registration: result).takeVerifiedOutput())
    }

    func testWrongSizedOrUnrequestedSecondPRFOutputIsRejected() throws {
        for count in [0, 31, 33, 64] {
            let key = SymmetricKey(data: Data(repeating: 1, count: count))
            XCTAssertThrowsError(try registrationResult(output: .init(first: key, second: nil)))
            XCTAssertThrowsError(try assertionResult(
                context: assertionContext(),
                output: .init(first: key, second: nil)
            ))
        }
        let key = SymmetricKey(data: secret)
        XCTAssertThrowsError(try registrationResult(output: .init(first: key, second: key)))
        XCTAssertThrowsError(try assertionResult(context: assertionContext(), output: .init(first: key, second: key)))
        XCTAssertThrowsError(try assertionResult(context: assertionContext(), output: nil))
    }

    func testAssertionRejectsWrongCredentialAndWrongCeremonyKind() throws {
        XCTAssertThrowsError(try assertionResult(context: assertionContext(), credential: Data([1])))
        XCTAssertThrowsError(try assertionResult(context: PasskeyBackupPRFContext.registration(
            registration(), prfSalt: salt
        )))
        XCTAssertThrowsError(
            try PasskeyBackupPRFEnrollmentGate(registration: assertionResult(context: assertionContext()))
        )
    }

    func testDirectedAssertionSerializesAbsentNativeUserHandleAsNull() throws {
        let result = try PasskeyBackupPRFCeremonyResult.assertion(
            context: assertionContext(), credentialID: credentialID,
            clientDataJSON: Data("public-client-data".utf8),
            authenticatorData: Data([1]), signature: Data([2]), userHandle: nil,
            prf: .init(first: SymmetricKey(data: secret), second: nil)
        )
        let credential = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(result.credentialResponseJSON.utf8)) as? [String: Any]
        )
        let response = try XCTUnwrap(credential["response"] as? [String: Any])
        XCTAssertTrue(response["userHandle"] is NSNull)
        XCTAssertFalse(result.credentialResponseJSON.contains("prf"))
        XCTAssertThrowsError(try PasskeyCredentialResponseSerializer.credentialDirectedAssertionJSON(
            credentialID: credentialID, allowedCredentialID: Data(repeating: 0x44, count: 32),
            clientDataJSON: Data([1]), authenticatorData: Data([2]), signature: Data([3]), userHandle: nil
        ))
        XCTAssertThrowsError(try PasskeyCredentialResponseSerializer.credentialDirectedAssertionJSON(
            credentialID: credentialID, allowedCredentialID: credentialID,
            clientDataJSON: Data([1]), authenticatorData: Data([2]), signature: Data([3]), userHandle: Data()
        ))
    }

    func testUnavailableVerifierNeverReleasesOutput() async throws {
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult(
            output: .init(first: SymmetricKey(data: secret), second: nil)
        ))
        do {
            try await gate.verifyRegistration()
            XCTFail("Unavailable verifier accepted native output")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .verificationUnavailable) }
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
        do {
            try await gate.verifyRegistration(using: FixturePRFVerifier())
            XCTFail("Failed gate was retried")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
    }

    func testVerifiedCreationOutputCanBeTakenOnceAndWrapsLocally() async throws {
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult(
            output: .init(first: SymmetricKey(data: secret), second: nil)
        ))
        let verifier = FixturePRFVerifier()
        try await gate.verifyRegistration(using: verifier)
        let output = try gate.takeVerifiedOutput()
        XCTAssertEqual(output.credentialID, credentialID)
        XCTAssertEqual(output.prfSalt, salt)
        XCTAssertEqual(output.storageKey, "wallet-1234")
        XCTAssertEqual(try output.withOutput { data -> Data in
            XCTAssertEqual(data, secret)
            let context = try PasskeyBackupKeyWrapperContext(
                ownerSubject: "owner:ERERERERERERERERERERERERERERERERERERERERERE",
                credentialId: base64URL(credentialID), keyEpoch: 7,
                envelopeMetadata: PasskeyBackupEnvelopeMetadata(
                    storageKey: "wallet-1234", walletId: "wallet-001", accountName: "alice@example.com",
                    createdAtMillis: 1_767_225_600_000
                )
            )
            let wrapper = PasskeyBackupCredentialKeyWrapper()
            let record = try wrapper.wrap(
                backupKey: Data(repeating: 0x77, count: 32),
                prfOutput: data,
                prfSalt: salt,
                context: context
            )
            return try wrapper.unwrap(record: record, prfOutput: data, expectedContext: context)
        }, Data(repeating: 0x77, count: 32))
        XCTAssertEqual(Mirror(reflecting: output).children.count, 0)
        XCTAssertEqual(String(reflecting: output), "PasskeyBackupVerifiedLocalPRF(<redacted>)")
        do {
            _ = try output.withOutput { $0 }
            XCTFail("A verified PRF result was reused")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
        XCTAssertEqual(verifier.requests.count, 1)
    }

    func testVerifiedPRFOutputIsBurnedWhenLocalUseThrows() async throws {
        let output = try await verifiedOutput()
        do {
            _ = try output.withOutput { _ -> Data in throw PasskeyBackupPRFError.invalidInput }
            XCTFail("Local failure did not propagate")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidInput) }
        do {
            _ = try output.withOutput { $0 }
            XCTFail("A failed use left PRF available")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
    }

    func testScopedKeyProviderUnwrapsOnceForExactCredentialAndMetadata() async throws {
        let generation = try generation()
        let record = try XCTUnwrap(generation.wrappers.first)
        let output = try await verifiedOutput()
        let provider = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: output, record: record, expectedContext: record.context
        )
        let metadata = try generation.envelope.envelopeMetadata()
        var key = try await provider.backupKey(for: metadata)
        XCTAssertEqual(key, Data(repeating: 0x77, count: 32))
        key.resetBytes(in: 0 ..< key.count)
        do {
            _ = try await provider.backupKey(for: metadata)
            XCTFail("Provider allowed a second unwrap")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        XCTAssertEqual(String(describing: provider), "PasskeyBackupVerifiedPRFKeyProvider(<redacted>)")
        XCTAssertEqual(Mirror(reflecting: provider).children.count, 0)
    }

    func testScopedKeyProviderRejectsSubstitutedOwnerEpochCredentialSaltAndMetadata() async throws {
        let generation = try generation()
        let record = try XCTUnwrap(generation.wrappers.first)
        let metadata = try generation.envelope.envelopeMetadata()
        let otherOwner = try PasskeyBackupKeyWrapperContext(
            ownerSubject: "owner:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            credentialId: record.context.credentialId, keyEpoch: record.context.keyEpoch,
            envelopeMetadata: metadata
        )
        let otherEpoch = try PasskeyBackupKeyWrapperContext(
            ownerSubject: record.context.ownerSubject,
            credentialId: record.context.credentialId, keyEpoch: record.context.keyEpoch + 1,
            envelopeMetadata: metadata
        )
        let boundOutput = try await verifiedOutput()
        for context in [otherOwner, otherEpoch] {
            XCTAssertThrowsError(try PasskeyBackupVerifiedPRFKeyProvider(
                verifiedPRF: boundOutput, record: record, expectedContext: context
            ))
        }
        let wrongCredential = try await verifiedOutput(credential: Data(repeating: 0x23, count: 32))
        XCTAssertThrowsError(try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: wrongCredential, record: record, expectedContext: record.context
        ))
        let wrongSalt = try PasskeyBackupCredentialKeyWrapperRecord(
            context: record.context, prfSalt: Data(repeating: 0x34, count: 32),
            hkdfSalt: record.hkdfSalt, nonce: record.nonce, ciphertextAndTag: record.ciphertextAndTag
        )
        let saltOutput = try await verifiedOutput()
        XCTAssertThrowsError(try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: saltOutput, record: wrongSalt, expectedContext: record.context
        ))
        let metadataOutput = try await verifiedOutput()
        let provider = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: metadataOutput, record: record, expectedContext: record.context
        )
        let otherMetadata = try PasskeyBackupEnvelopeMetadata(
            storageKey: metadata.storageKey, walletId: "wallet-9999", accountName: metadata.accountName,
            createdAtMillis: metadata.createdAtMillis
        )
        do {
            _ = try await provider.backupKey(for: otherMetadata)
            XCTFail("Provider accepted a different wallet")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupVerifiedPRFKeyProviderError, .bindingMismatch)
        }
        do {
            _ = try await provider.backupKey(for: metadata)
            XCTFail("Failed lookup remained usable")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        let replacementProvider = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: metadataOutput, record: record, expectedContext: record.context
        )
        do {
            _ = try await replacementProvider.backupKey(for: metadata)
            XCTFail("A metadata mismatch left the PRF reusable through another provider")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
    }

    func testVerifiedPRFOutputCannotBeReplayedThroughAnotherProvider() async throws {
        let generation = try generation()
        let record = try XCTUnwrap(generation.wrappers.first)
        let output = try await verifiedOutput()
        let first = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: output, record: record, expectedContext: record.context
        )
        let second = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: output, record: record, expectedContext: record.context
        )
        let metadata = try generation.envelope.envelopeMetadata()
        var key = try await first.backupKey(for: metadata)
        key.resetBytes(in: 0 ..< key.count)
        do {
            _ = try await second.backupKey(for: metadata)
            XCTFail("Another provider replayed the native PRF result")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
    }

    func testCancelledScopedProviderBurnsVerifiedPRFForEveryProvider() async throws {
        let generation = try generation()
        let record = try XCTUnwrap(generation.wrappers.first)
        let output = try await verifiedOutput()
        let first = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: output, record: record, expectedContext: record.context
        )
        let second = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: output, record: record, expectedContext: record.context
        )
        let metadata = try generation.envelope.envelopeMetadata()
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await first.backupKey(for: metadata)
        }
        do {
            _ = try await cancelled.value
            XCTFail("Cancelled key access succeeded")
        } catch is CancellationError {} catch { XCTFail("Unexpected cancellation error: \(error)") }
        for provider in [first, second] {
            do {
                _ = try await provider.backupKey(for: metadata)
                XCTFail("Cancellation left verified PRF available")
            } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        }
    }

    func testVerifiedPRFDecryptsSharedGenerationAndRequiresOriginalKeyEvidence() async throws {
        let local = FixturePlaintextWalletVerifier()
        let verifier = PasskeyBackupGenerationCryptographicVerifier(walletVerifier: local)
        let identity = try PasskeyBackupExpectedWalletIdentity(
            storageKey: "wallet-1234", walletId: "wallet-001",
            publicIdentitySha256: String(repeating: "b", count: 64)
        )
        let output = try await verifiedOutput()
        let evidence = try await verifier.verify(
            generation(), verifiedPRF: output, expectedIdentity: identity
        )
        XCTAssertEqual(evidence.publicIdentitySha256, identity.publicIdentitySha256)
        XCTAssertEqual(local.calls, 1)
        XCTAssertEqual(local.lastPlaintext, Data("cross-platform-passkey-backup".utf8))
    }

    func testGenerationVerificationRejectsWrongCredentialPRFAndWalletEvidence() async throws {
        let local = FixturePlaintextWalletVerifier()
        let verifier = PasskeyBackupGenerationCryptographicVerifier(walletVerifier: local)
        let identity = try PasskeyBackupExpectedWalletIdentity(
            storageKey: "wallet-1234", walletId: "wallet-001",
            publicIdentitySha256: String(repeating: "b", count: 64)
        )
        let wrongCredential = try await verifiedOutput(credential: Data(repeating: 0x23, count: 32))
        let wrongPRF = try await verifiedOutput(prf: Data(repeating: 0x67, count: 32))
        for output in [wrongCredential, wrongPRF] {
            do {
                _ = try await verifier.verify(generation(), verifiedPRF: output, expectedIdentity: identity)
                XCTFail("Unrelated credential or PRF opened a generation")
            } catch {}
        }
        XCTAssertEqual(local.calls, 0)
        let otherWallet = try PasskeyBackupExpectedWalletIdentity(
            storageKey: "wallet-9999", walletId: "wallet-001",
            publicIdentitySha256: identity.publicIdentitySha256
        )
        let validOutput = try await verifiedOutput()
        do {
            _ = try await verifier.verify(
                generation(), verifiedPRF: validOutput, expectedIdentity: otherWallet
            )
            XCTFail("Wrong wallet identity accepted")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupGenerationCoordinatorError, .walletIdentityMismatch)
        }
        XCTAssertEqual(local.calls, 0)
        local.failedCheck = 1
        do {
            _ = try await verifier.verify(
                generation(), verifiedPRF: validOutput, expectedIdentity: identity
            )
            XCTFail("Missing original-key signing evidence accepted")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupGenerationCoordinatorError, .localVerificationFailed)
        }
        XCTAssertEqual(local.calls, 1)
    }

    func testMissingCreationOutputNeedsFreshVerifiedSameCredentialAssertion() async throws {
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult())
        XCTAssertThrowsError(try gate.assertionContext(assertion()))
        let verifier = FixturePRFVerifier()
        try await gate.verifyRegistration(using: verifier)
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
        let context = try gate.assertionContext(assertion())
        XCTAssertEqual(context.expectedCredentialID, credentialID)
        XCTAssertEqual(context.prfSalt, salt)
        XCTAssertThrowsError(try gate.assertionContext(assertion()))
        let result = try assertionResult(context: context)
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
        try await gate.verifyAssertion(result, using: verifier)
        XCTAssertEqual(try gate.takeVerifiedOutput().withOutput { $0 }, secret)
        XCTAssertEqual(verifier.requests.map(\.context.kind), [.registration, .assertion])
        XCTAssertNotEqual(verifier.requests[0].bindingSHA256, verifier.requests[1].bindingSHA256)
    }

    func testFallbackRejectsReusedChallengeIDAndOtherStorageBeforeRequest() async throws {
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult())
        try await gate.verifyRegistration(using: FixturePRFVerifier())
        let pending = try registration()
        for request in try [
            assertion(id: pending.registrationId), assertion(challenge: pending.challenge),
            assertion(storage: "wallet-5678")
        ] {
            XCTAssertThrowsError(try gate.assertionContext(request))
        }
        XCTAssertNoThrow(try gate.assertionContext(assertion()))
    }

    func testFallbackRejectsDifferentRequestTranscriptAndUnavailableVerification() async throws {
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult())
        try await gate.verifyRegistration(using: FixturePRFVerifier())
        let expected = try gate.assertionContext(assertion())
        let wrong = try PasskeyBackupPRFContext.assertion(
            assertion(id: "assertion-other"), prfSalt: salt, credentialID: credentialID
        )
        do {
            try await gate.verifyAssertion(assertionResult(context: wrong), using: FixturePRFVerifier())
            XCTFail("Mismatched context accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        do {
            try await gate.verifyAssertion(assertionResult(context: expected))
            XCTFail("Unavailable assertion verifier accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .verificationUnavailable) }
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
    }

    func testWrongReceiptBindingAndCredentialFailClosed() async throws {
        for mode in [FixturePRFVerifier.Mode.wrongBinding, .wrongCredential] {
            let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult(
                output: .init(first: SymmetricKey(data: secret), second: nil)
            ))
            do {
                try await gate.verifyRegistration(using: FixturePRFVerifier(mode: mode))
                XCTFail("Substituted receipt accepted")
            } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .verificationMismatch) }
            XCTAssertThrowsError(try gate.takeVerifiedOutput())
        }
    }

    func testChallengeServiceVerifierCompletesBoundCeremoniesWithoutPRFMaterial() async throws {
        let service = FixturePRFChallengeService(storageKey: "wallet-1234")
        let verifier = ChallengeServicePasskeyBackupPRFVerifier(service: service)
        let registration = try registrationResult(output: .init(
            first: SymmetricKey(data: secret), second: nil
        ))
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registration)
        try await gate.verifyRegistration(using: verifier)
        XCTAssertEqual(service.registrationID, registration.context.ceremonyId)
        XCTAssertEqual(service.registrationJSON, registration.credentialResponseJSON)
        XCTAssertFalse(try XCTUnwrap(service.registrationJSON).contains("prf"))
        XCTAssertEqual(try gate.takeVerifiedOutput().withOutput { $0 }, secret)

        let assertion = try assertionResult(context: assertionContext())
        let request = PasskeyBackupPRFVerificationRequest(result: assertion)
        let receipt = try await verifier.verify(request)
        XCTAssertEqual(receipt.requestBindingSHA256, request.bindingSHA256)
        XCTAssertEqual(receipt.credentialID, credentialID)
        XCTAssertEqual(service.assertionID, assertion.context.ceremonyId)
        XCTAssertEqual(service.assertionJSON, assertion.credentialResponseJSON)
    }

    func testChallengeServiceVerifierRejectsMismatchedStorageBeforeReleasingPRF() async throws {
        let service = FixturePRFChallengeService(storageKey: "wallet-5678")
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult(output: .init(
            first: SymmetricKey(data: secret), second: nil
        )))
        do {
            try await gate.verifyRegistration(using: ChallengeServicePasskeyBackupPRFVerifier(service: service))
            XCTFail("Mismatched server result released PRF output")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .verificationMismatch) }
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
    }

    func testVerificationCannotRaceDuplicateOrCancellation() async throws {
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult(
            output: .init(first: SymmetricKey(data: secret), second: nil)
        ))
        let verifier = FixturePRFVerifier(mode: .suspended)
        let task = Task { try await gate.verifyRegistration(using: verifier) }
        await verifier.waitForRequest()
        do {
            try await gate.verifyRegistration(using: verifier)
            XCTFail("Concurrent verification accepted")
        } catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .invalidState) }
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
        task.cancel()
        verifier.resume()
        do { try await task.value; XCTFail("Cancelled verification released output") } catch {}
        XCTAssertThrowsError(try gate.takeVerifiedOutput())
        XCTAssertEqual(verifier.requests.count, 1)
    }

    func testVerificationBindingCoversPublicTranscriptAndCredential() throws {
        let result = try registrationResult()
        let request = PasskeyBackupPRFVerificationRequest(result: result)
        let otherCredential = try PasskeyBackupPRFCeremonyResult.registration(
            context: result.context, credentialID: Data([1]),
            clientDataJSON: Data("public-client-data".utf8), attestationObject: Data([1, 2, 3]), prf: nil
        )
        let otherTranscript = try PasskeyBackupPRFCeremonyResult.registration(
            context: result.context, credentialID: credentialID,
            clientDataJSON: Data("public-client-data ".utf8), attestationObject: Data([1, 2, 3]), prf: nil
        )
        XCTAssertEqual(request.bindingSHA256.count, 32)
        XCTAssertNotEqual(
            request.bindingSHA256,
            PasskeyBackupPRFVerificationRequest(result: otherCredential).bindingSHA256
        )
        XCTAssertNotEqual(
            request.bindingSHA256,
            PasskeyBackupPRFVerificationRequest(result: otherTranscript).bindingSHA256
        )
        XCTAssertEqual(String(describing: result.context), "PasskeyBackupPRFContext(<redacted>)")
    }

    func testProductionExecutorIsDisabledBeforePresentingNativeUI() async throws {
        var presentations = 0
        let executor = ASPasskeyBackupPRFExecutor { _, _, _ in
            presentations += 1
            return FixturePRFSession()
        }
        do { _ = try await executor.performRegistration(registration(), prfSalt: salt); XCTFail() }
        catch { XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled) }
        do { _ = try await executor.performAssertion(assertionContext()); XCTFail() }
        catch { XCTAssertEqual(error as? PasskeyBackupError, .passkeyBackupDisabled) }
        XCTAssertEqual(presentations, 0)
        XCTAssertFalse(PasskeyBackupReleaseConfig.isPasskeyBackupEnabled)
    }

    func testExecutorUsesNativeRequestsAndReturnsTypedResultOnce() async throws {
        let result = try registrationResult()
        let executor = ASPasskeyBackupPRFExecutor(isReleaseEnabled: true) { request, context, completion in
            XCTAssertNotNil(request as? ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest)
            XCTAssertEqual(context, result.context)
            return FixturePRFSession {
                completion(.success(result))
                completion(.failure(PasskeyBackupPRFError.ceremonyFailed))
            }
        }
        let actual = try await executor.performRegistration(registration(), prfSalt: salt)
        XCTAssertTrue(actual === result)
    }

    func testExecutorCancellationAndLateCompletionCannotSettleNextCeremony() async throws {
        var sessions: [FixturePRFSession] = []
        var completions: [ASPasskeyBackupPRFExecutor.Completion] = []
        let started = expectation(description: "first started")
        let secondStarted = expectation(description: "second started")
        let executor = ASPasskeyBackupPRFExecutor(isReleaseEnabled: true) { _, _, completion in
            let session = FixturePRFSession {
                if sessions.count == 1 { started.fulfill() } else { secondStarted.fulfill() }
            }
            sessions.append(session)
            completions.append(completion)
            return session
        }
        let pending = try registration()
        let task = Task { try await executor.performRegistration(pending, prfSalt: salt) }
        await fulfillment(of: [started], timeout: 2)
        do { _ = try await executor.performRegistration(pending, prfSalt: salt); XCTFail() }
        catch { XCTAssertEqual(error as? PasskeyBackupError, .ceremonyInProgress) }
        task.cancel()
        do { _ = try await task.value; XCTFail() } catch {}
        XCTAssertEqual(sessions[0].cancellations, 1)
        let next = Task { try await executor.performRegistration(pending, prfSalt: salt) }
        await fulfillment(of: [secondStarted], timeout: 2)
        completions[0](.success(try registrationResult()))
        completions[1](.failure(PasskeyBackupPRFError.ceremonyFailed))
        do { _ = try await next.value; XCTFail("Stale result settled next request") }
        catch { XCTAssertEqual(error as? PasskeyBackupPRFError, .ceremonyFailed) }
        XCTAssertEqual(sessions[1].cancellations, 0)
    }

    func testAlreadyCancelledExecutorDoesNotCreateSession() async throws {
        var presentations = 0
        let executor = ASPasskeyBackupPRFExecutor(isReleaseEnabled: true) { _, _, _ in
            presentations += 1
            return FixturePRFSession()
        }
        let pending = try registration()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await executor.performRegistration(pending, prfSalt: salt)
        }
        do { _ = try await task.value; XCTFail() } catch {}
        XCTAssertEqual(presentations, 0)
    }

    private func registration() throws -> PendingPasskeyBackupRegistration {
        try PendingPasskeyBackupRegistration(challenge: PasskeyBackupRegistrationChallenge(
            registrationId: "registration-one", challenge: Data(repeating: 1, count: 32),
            userId: Data(repeating: 2, count: 32), userName: "alice@example.com",
            displayName: "Alice", storageKey: "wallet-1234"
        ), walletId: "wallet-001", accountName: "alice@example.com")
    }

    private func assertion(
        id: String = "assertion-two", challenge: Data = Data(repeating: 3, count: 32),
        storage: String = "wallet-1234", directed: Bool = true
    ) throws -> PendingPasskeyBackupAssertion {
        try PendingPasskeyBackupAssertion(challenge: PasskeyBackupAssertionChallenge(
            assertionId: id, challenge: challenge, storageKey: storage,
            credentialId: directed ? base64URL(credentialID) : nil
        ))
    }

    private func assertionContext() throws -> PasskeyBackupPRFContext {
        try PasskeyBackupPRFContext.assertion(assertion(), prfSalt: salt, credentialID: credentialID)
    }

    private func registrationResult(
        output: ASAuthorizationPublicKeyCredentialPRFRegistrationOutput? = nil,
        credential: Data? = nil
    ) throws -> PasskeyBackupPRFCeremonyResult {
        try .registration(
            context: PasskeyBackupPRFContext.registration(registration(), prfSalt: salt),
            credentialID: credential ?? credentialID,
            clientDataJSON: Data("public-client-data".utf8),
            attestationObject: Data([1, 2, 3]),
            prf: output
        )
    }

    private func verifiedOutput(
        prf: Data = Data(repeating: 0x66, count: 32),
        credential: Data? = nil
    ) async throws -> PasskeyBackupVerifiedLocalPRF {
        let gate = try PasskeyBackupPRFEnrollmentGate(registration: registrationResult(
            output: .init(first: SymmetricKey(data: prf), second: nil), credential: credential
        ))
        try await gate.verifyRegistration(using: FixturePRFVerifier())
        return try gate.takeVerifiedOutput()
    }

    private func generation() throws -> PasskeyBackupGenerationV1 {
        let owner = "owner:ERERERERERERERERERERERERERERERERERERERERERE"
        let metadata = try PasskeyBackupEnvelopeMetadata(
            storageKey: "wallet-1234", walletId: "wallet-001", accountName: "alice@example.com",
            createdAtMillis: 1_767_225_600_000
        )
        let envelope = try PasskeyBackupEncryptedRecord(
            storageKey: metadata.storageKey, walletId: metadata.walletId,
            accountName: metadata.accountName, createdAtMillis: metadata.createdAtMillis,
            encryptedPayload: PasskeyBackupContract.decodeBase64URL(
                "RlBCS0FFQUQBAQwQAAAAHQABAgMEBQYHCAkKC83JBCkpwJEyw__KPV-GpFaKNXesucIWrPbymd1fJxz0FX_uLctQsHJRM3AfVA"
            )
        )
        let wrapper = try PasskeyBackupCredentialKeyWrapperRecord(
            context: PasskeyBackupKeyWrapperContext(
                ownerSubject: owner, credentialId: base64URL(credentialID), keyEpoch: 7,
                envelopeMetadata: metadata
            ),
            prfSalt: salt, hkdfSalt: Data(repeating: 0x44, count: 32),
            nonce: Data(repeating: 0x55, count: 12),
            ciphertextAndTag: PasskeyBackupContract.decodeBase64URL(
                "m_xnd6ezMk5VjmGJjqjAVrBDJYQTp7NxcktIT8CmyM8uzo4ZphIMYP-2QRflGgs5"
            )
        )
        return try PasskeyBackupGenerationV1(
            context: PasskeyBackupGenerationV1.Context(
                ownerSubject: owner,
                backupNamespace: "backup:iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIg",
                generationId: "mZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZk",
                parentHeadRevision: 6, parentHeadSha256: String(repeating: "a", count: 64),
                keyEpoch: 7,
                storageAccountBinding: PasskeyBackupGenerationV1Format.storageAccountBinding(
                    verifiedGoogleSubject: "google-subject-123"
                )
            ),
            envelope: envelope, wrappers: [wrapper]
        )
    }

    private func assertionResult(
        context: PasskeyBackupPRFContext, credential: Data? = nil,
        output: ASAuthorizationPublicKeyCredentialPRFAssertionOutput? = .init(
            first: SymmetricKey(data: Data(repeating: 0x66, count: 32)), second: nil
        )
    ) throws -> PasskeyBackupPRFCeremonyResult {
        try .assertion(
            context: context,
            credentialID: credential ?? credentialID,
            clientDataJSON: Data("public-client-data".utf8),
            authenticatorData: Data([1]),
            signature: Data([2]),
            userHandle: Data(repeating: 2, count: 32),
            prf: output
        )
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

private final class FixturePlaintextWalletVerifier: PasskeyBackupPlaintextWalletVerifier {
    var calls = 0
    var failedCheck: Int?
    var lastPlaintext: Data?

    func verifyOriginalWallet(
        _ plaintextBackup: Data,
        expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyBackupLocalWalletEvidence {
        calls += 1
        lastPlaintext = plaintextBackup
        guard plaintextBackup == Data("cross-platform-passkey-backup".utf8) else {
            throw PasskeyBackupGenerationCoordinatorError.localVerificationFailed
        }
        return PasskeyBackupLocalWalletEvidence(
            storageKey: expectedIdentity.storageKey,
            walletId: expectedIdentity.walletId,
            publicIdentitySha256: expectedIdentity.publicIdentitySha256,
            decryptionVerified: failedCheck != 0,
            originalKeySigningVerified: failedCheck != 1,
            originalKeyExportVerified: failedCheck != 2
        )
    }
}

@MainActor
private final class FixturePRFVerifier: PasskeyBackupPRFVerifier {
    enum Mode { case valid, wrongBinding, wrongCredential, suspended }
    var requests: [PasskeyBackupPRFVerificationRequest] = []
    private let mode: Mode
    private var continuation: CheckedContinuation<Void, Never>?
    init(mode: Mode = .valid) { self.mode = mode }
    func verify(_ request: PasskeyBackupPRFVerificationRequest) async throws -> PasskeyBackupPRFVerificationReceipt {
        requests.append(request)
        if mode == .suspended { await withCheckedContinuation { continuation = $0 } }
        return PasskeyBackupPRFVerificationReceipt(
            requestBindingSHA256: mode == .wrongBinding ? Data(repeating: 0, count: 32) : request.bindingSHA256,
            credentialID: mode == .wrongCredential ? Data([1]) : request.credentialID
        )
    }

    func waitForRequest() async {
        for _ in 0 ..< 1000 {
            if continuation != nil { return }
            await Task.yield()
        }
        XCTFail("Verifier did not suspend")
    }

    func resume() { continuation?.resume(); continuation = nil }
}

private final class FixturePRFChallengeService: PasskeyBackupChallengeService {
    let storageKey: String
    private(set) var registrationID: String?
    private(set) var registrationJSON: String?
    private(set) var assertionID: String?
    private(set) var assertionJSON: String?

    init(storageKey: String) { self.storageKey = storageKey }

    func registrationChallenge(
        walletId _: String, accountName _: String, displayName _: String
    ) async throws -> PasskeyBackupRegistrationChallenge {
        throw PasskeyBackupError.unavailableAuthorization
    }

    func completeRegistration(
        registrationId: String, credentialResponseJSON: String
    ) async throws -> PasskeyBackupChallengeResult {
        registrationID = registrationId
        registrationJSON = credentialResponseJSON
        return try PasskeyBackupChallengeResult(storageKey: storageKey)
    }

    func assertionChallenge(storageKey _: String) async throws -> PasskeyBackupAssertionChallenge {
        throw PasskeyBackupError.unavailableAuthorization
    }

    func completeAssertion(
        assertionId: String, credentialResponseJSON: String
    ) async throws -> PasskeyBackupChallengeResult {
        assertionID = assertionId
        assertionJSON = credentialResponseJSON
        return try PasskeyBackupChallengeResult(storageKey: storageKey)
    }
}

@available(iOS 18.0, *)
@MainActor
private final class FixturePRFSession: PasskeyBackupPRFAuthorizationSession {
    private let action: () -> Void
    private(set) var cancellations = 0
    init(action: @escaping () -> Void = {}) { self.action = action }
    func start() { action() }
    func cancel() { cancellations += 1 }
}
