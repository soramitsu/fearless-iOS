import AuthenticationServices
import CryptoKit
import XCTest
@testable import fearless

final class PasskeyCredentialResponseSerializerTests: XCTestCase {
    func testRegistrationSerializerProducesWebAuthnEnvelopeAndBase64URLFields() throws {
        let json = try PasskeyCredentialResponseSerializer.registrationJSON(
            credentialID: Data([0xFB, 0xFF]),
            clientDataJSON: Data([0x00, 0x01]),
            attestationObject: Data([0x02, 0x03]),
            authenticatorData: Data([0x04, 0x05])
        )
        let credential = try jsonObject(json)
        let response = try XCTUnwrap(credential["response"] as? [String: Any])
        let extensions = try XCTUnwrap(credential["clientExtensionResults"] as? [String: Any])

        XCTAssertEqual(
            Set(credential.keys),
            Set([
                "id", "rawId", "response", "type",
                "clientExtensionResults", "authenticatorAttachment"
            ])
        )
        XCTAssertEqual(credential["id"] as? String, "-_8")
        XCTAssertEqual(credential["rawId"] as? String, "-_8")
        XCTAssertEqual(credential["type"] as? String, "public-key")
        XCTAssertEqual(credential["authenticatorAttachment"] as? String, "platform")
        XCTAssertTrue(extensions.isEmpty)
        XCTAssertEqual(
            Set(response.keys),
            Set(["clientDataJSON", "attestationObject", "authenticatorData"])
        )
        XCTAssertEqual(response["clientDataJSON"] as? String, "AAE")
        XCTAssertEqual(response["attestationObject"] as? String, "AgM")
        XCTAssertEqual(response["authenticatorData"] as? String, "BAU")
    }

    func testChallengeClientAuthorizesExactTransmittedBody() async throws {
        let challenge = Data(repeating: 7, count: 32)
        let userID = Data(repeating: 8, count: 32)
        let response = """
        {
          "registrationId":"registration-1234",
          "challenge":"\(base64URL(challenge))",
          "userId":"\(base64URL(userID))",
          "userName":"alice@example.com",
          "displayName":"Alice",
          "storageKey":"wallet-1234",
          "rpId":"fearlesswallet.io",
          "schemaVersion":1
        }
        """
        let transport = AuthorizationTestTransport(
            responses: [PasskeyBackupHTTPResponse(statusCode: 200, body: Data(response.utf8))]
        )
        let authorization = AuthorizationTestProvider(token: "test.authorization-token_123")
        let service = try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: transport,
            authorizationProvider: authorization
        )

        _ = try await service.registrationChallenge(
            walletId: "wallet-001",
            accountName: "alice@example.com",
            displayName: "Alice"
        )

        let request = try XCTUnwrap(transport.requests.first)
        let authorizationRequest = try XCTUnwrap(authorization.requests.first)
        XCTAssertEqual(request.headers["Authorization"], "Bearer test.authorization-token_123")
        XCTAssertEqual(authorizationRequest.method, "POST")
        XCTAssertEqual(
            authorizationRequest.path,
            "/api/passkey-backup/v1/registration/challenge"
        )
        XCTAssertEqual(
            authorizationRequest.bodySha256,
            sha256Base64URL(try XCTUnwrap(request.body))
        )
    }

    func testChallengeClientFailsClosedWithoutAuthorizationProvider() async throws {
        let transport = AuthorizationTestTransport(responses: [])
        let service = try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: transport
        )

        do {
            _ = try await service.assertionChallenge(storageKey: "wallet-1234")
            XCTFail("Unavailable authorization provider unexpectedly allowed a request")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .unavailableAuthorization)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testChallengeClientRejectsOversizedInjectedTransportResponsesBeforeStatusOrJSON() async throws {
        for statusCode in [200, 503] {
            let transport = AuthorizationTestTransport(
                responses: [
                    PasskeyBackupHTTPResponse(
                        statusCode: statusCode,
                        body: Data(
                            repeating: 0x41,
                            count: PasskeyBackupHTTPTransportPolicy.maximumResponseBytes + 1
                        )
                    )
                ]
            )
            let service = try HTTPPasskeyBackupChallengeService(
                baseURL: "https://backup.fearlesswallet.io",
                transport: transport,
                authorizationProvider: AuthorizationTestProvider(token: "test-token")
            )

            do {
                _ = try await service.assertionChallenge(storageKey: "wallet-1234")
                XCTFail("Oversized response unexpectedly passed for HTTP \(statusCode)")
            } catch {
                XCTAssertEqual(
                    error as? PasskeyBackupError,
                    .challengeServiceResponseTooLarge
                )
            }
        }
    }

    func testChallengeClientRejectsMalformedBearerTokensBeforeTransport() async throws {
        let malformedTokens = [
            "",
            " token",
            "token ",
            "two tokens",
            "token\nvalue",
            "token,value",
            "Bearer token",
            "abc=def",
            String(repeating: "a", count: 4097)
        ]

        for token in malformedTokens {
            let transport = AuthorizationTestTransport(responses: [])
            let service = try HTTPPasskeyBackupChallengeService(
                baseURL: "https://backup.fearlesswallet.io",
                transport: transport,
                authorizationProvider: AuthorizationTestProvider(token: token)
            )

            do {
                _ = try await service.assertionChallenge(storageKey: "wallet-1234")
                XCTFail("Malformed token unexpectedly allowed: \(token.prefix(32))")
            } catch {
                XCTAssertEqual(error as? PasskeyBackupError, .invalidAuthorizationToken)
            }
            XCTAssertTrue(transport.requests.isEmpty)
        }
    }

    func testAuthorizationRequestAcceptsOnlyExactServicePaths() throws {
        let digest = base64URL(Data(repeating: 0, count: 32))
        let allowedPaths = [
            PasskeyBackupAuthorizationRequest.registrationChallengePath,
            PasskeyBackupAuthorizationRequest.registrationCompletePath,
            PasskeyBackupAuthorizationRequest.assertionChallengePath,
            PasskeyBackupAuthorizationRequest.assertionCompletePath,
            PasskeyBackupAuthorizationRequest.credentialsListPath,
            PasskeyBackupAuthorizationRequest.credentialsRevokePath,
            PasskeyBackupAuthorizationRequest.credentialsRevokeAllPath
        ]
        for path in allowedPaths {
            XCTAssertNoThrow(
                try PasskeyBackupAuthorizationRequest(
                    method: "POST",
                    path: path,
                    bodySha256: digest
                )
            )
        }

        let rejectedPaths = [
            "/api/passkey-backup/v1/registration/challenge/extra",
            "/api/passkey-backup/v1/registration/../assertion/challenge",
            "/api/passkey-backup/v1/%2e%2e/admin",
            "/api/passkey-backup/v1/admin",
            "/api/passkey-backup/v1/assertion/challenge?scope=admin",
            "/api/passkey-backup/v1/credentials/revoke-all?admin=true",
            "/api/passkey-backup/v1/credentials/revoke-all/",
            "/api/passkey-backup/v1/credentials/revoke-all%2F..%2Flist",
            "//api/passkey-backup/v1/assertion/challenge",
            "https://backup.fearlesswallet.io/api/passkey-backup/v1/assertion/challenge",
            ""
        ]
        for path in rejectedPaths {
            XCTAssertThrowsError(
                try PasskeyBackupAuthorizationRequest(
                    method: "POST",
                    path: path,
                    bodySha256: digest
                ),
                "Unexpectedly accepted authorization path: \(path)"
            )
        }
    }

    func testAuthorizationRequestRejectsNoncanonicalBodyDigests() {
        let path = PasskeyBackupAuthorizationRequest.assertionChallengePath
        let canonicalDigest = base64URL(Data(repeating: 0, count: 32))
        let rejectedDigests = [
            String(canonicalDigest.dropLast()),
            canonicalDigest + "=",
            String(canonicalDigest.dropLast()) + "B",
            String(canonicalDigest.dropLast()) + "+",
            " " + canonicalDigest,
            ""
        ]
        for digest in rejectedDigests {
            XCTAssertThrowsError(
                try PasskeyBackupAuthorizationRequest(
                    method: "POST",
                    path: path,
                    bodySha256: digest
                ),
                "Unexpectedly accepted authorization digest: \(digest)"
            )
        }
    }

    func testBase64URLDecoderRejectsAliasesPaddingAndWhitespace() throws {
        XCTAssertEqual(try PasskeyBackupContract.decodeBase64URL("-_8"), Data([0xFB, 0xFF]))
        for value in ["-_8=", "+/8=", " -_8", "-_8 ", "A"] {
            XCTAssertThrowsError(try PasskeyBackupContract.decodeBase64URL(value))
        }
    }

    func testAccountAndDisplayNameValidationMatchesPublicContract() throws {
        XCTAssertThrowsError(try PasskeyBackupContract.validateAccountName("alice@@example.com"))
        XCTAssertThrowsError(
            try PasskeyBackupRegistrationChallenge(
                registrationId: "registration-1234",
                challenge: Data(repeating: 1, count: 32),
                userId: Data(repeating: 2, count: 32),
                userName: "alice@example.com",
                displayName: String(repeating: "A", count: 129),
                storageKey: "wallet-1234"
            )
        )
    }

    func testChallengeClientRejectsFractionalSchemaVersion() async throws {
        let response = """
        {
          "registrationId":"registration-1234",
          "challenge":"\(base64URL(Data(repeating: 1, count: 32)))",
          "userId":"\(base64URL(Data(repeating: 2, count: 32)))",
          "userName":"alice@example.com",
          "displayName":"Alice",
          "storageKey":"wallet-1234",
          "rpId":"fearlesswallet.io",
          "schemaVersion":1.5
        }
        """
        let transport = AuthorizationTestTransport(
            responses: [PasskeyBackupHTTPResponse(statusCode: 200, body: Data(response.utf8))]
        )
        let service = try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: transport,
            authorizationProvider: AuthorizationTestProvider(token: "test-token")
        )

        do {
            _ = try await service.registrationChallenge(
                walletId: "wallet-001",
                accountName: "alice@example.com",
                displayName: "Alice"
            )
            XCTFail("Fractional schemaVersion unexpectedly passed")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .malformedChallengeServiceResponse)
        }
    }

    func testChallengeClientRejectsNon200SuccessStatuses() async throws {
        let response = """
        {
          "assertionId":"assertion-1234",
          "challenge":"\(base64URL(Data(repeating: 1, count: 32)))",
          "storageKey":"wallet-1234",
          "rpId":"fearlesswallet.io",
          "schemaVersion":1
        }
        """

        for statusCode in [201, 204] {
            let transport = AuthorizationTestTransport(
                responses: [
                    PasskeyBackupHTTPResponse(
                        statusCode: statusCode,
                        body: Data(response.utf8)
                    )
                ]
            )
            let service = try HTTPPasskeyBackupChallengeService(
                baseURL: "https://backup.fearlesswallet.io",
                transport: transport,
                authorizationProvider: AuthorizationTestProvider(token: "test-token")
            )

            do {
                _ = try await service.assertionChallenge(storageKey: "wallet-1234")
                XCTFail("HTTP \(statusCode) unexpectedly passed")
            } catch {
                XCTAssertEqual(
                    error as? PasskeyBackupError,
                    .challengeServiceHTTPStatus(statusCode)
                )
            }
        }
    }

    func testRegistrationCompletionDistinguishesExplicitRejectionFromUncertainSuccessResponse() async throws {
        for statusCode in [400, 401, 403, 404, 409, 422] {
            let explicit = try HTTPPasskeyBackupChallengeService(
                baseURL: "https://backup.fearlesswallet.io",
                transport: AuthorizationTestTransport(
                    responses: [PasskeyBackupHTTPResponse(statusCode: statusCode, body: Data())]
                ),
                authorizationProvider: AuthorizationTestProvider(token: "test-token")
            )
            do {
                _ = try await explicit.completeRegistration(
                    registrationId: "registration-1234",
                    credentialResponseJSON: #"{"id":"credential"}"#
                )
                XCTFail("Explicit registration rejection unexpectedly passed")
            } catch {
                XCTAssertEqual(
                    error as? PasskeyBackupError,
                    .challengeServiceHTTPStatus(statusCode)
                )
            }
        }

        let uncertainResponses = [
            PasskeyBackupHTTPResponse(statusCode: 408, body: Data()),
            PasskeyBackupHTTPResponse(statusCode: 425, body: Data()),
            PasskeyBackupHTTPResponse(statusCode: 429, body: Data()),
            PasskeyBackupHTTPResponse(statusCode: 500, body: Data()),
            PasskeyBackupHTTPResponse(statusCode: 503, body: Data()),
            PasskeyBackupHTTPResponse(statusCode: 200, body: Data()),
            PasskeyBackupHTTPResponse(
                statusCode: 200,
                body: Data(#"{"not":"the-contract"}"#.utf8)
            )
        ]
        for response in uncertainResponses {
            let uncertain = try HTTPPasskeyBackupChallengeService(
                baseURL: "https://backup.fearlesswallet.io",
                transport: AuthorizationTestTransport(
                    responses: [response]
                ),
                authorizationProvider: AuthorizationTestProvider(token: "test-token")
            )
            do {
                _ = try await uncertain.completeRegistration(
                    registrationId: "registration-1234",
                    credentialResponseJSON: #"{"id":"credential"}"#
                )
                XCTFail("Uncertain registration response unexpectedly passed")
            } catch {
                XCTAssertEqual(
                    error as? PasskeyBackupError,
                    .registrationCompletionOutcomeUnknown
                )
            }
        }
    }

    func testHTTP500AfterCommittedRegistrationTriggersCredentialCompensation() async throws {
        let credentialId = "Y3JlZC0x"
        let transport = AuthorizationTestTransport(
            responses: [
                PasskeyBackupHTTPResponse(statusCode: 500, body: Data()),
                httpJSON(
                    #"{"storageKey":"wallet-1234","credentialId":"\#(credentialId)","remainingCredentials":0,"rpId":"fearlesswallet.io","schemaVersion":1}"#
                )
            ]
        )
        let authorization = AuthorizationTestProvider(token: "test-token")
        let service = try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: transport,
            authorizationProvider: authorization
        )
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: LifecycleTestCloudStorage(record: nil),
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )

        do {
            _ = try await workflow.finishRegistrationWithPlaintext(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"\#(credentialId)"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
            XCTFail("Committed-then-500 registration unexpectedly passed")
        } catch {
            XCTAssertEqual(
                error as? PasskeyBackupError,
                .registrationCompletionOutcomeUnknown
            )
        }

        XCTAssertEqual(
            authorization.requests.map(\.path),
            [
                PasskeyBackupAuthorizationRequest.registrationCompletePath,
                PasskeyBackupAuthorizationRequest.credentialsRevokePath
            ]
        )
        XCTAssertEqual(transport.requests.count, 2)
        let revokeBody = try XCTUnwrap(transport.requests[1].body)
        let revokeJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: revokeBody) as? [String: Any]
        )
        XCTAssertEqual(revokeJSON["credentialId"] as? String, credentialId)
    }

    func testChallengeClientRejectsUnknownResponseFields() async throws {
        let response = """
        {
          "assertionId":"assertion-1234",
          "challenge":"\(base64URL(Data(repeating: 1, count: 32)))",
          "storageKey":"wallet-1234",
          "rpId":"fearlesswallet.io",
          "schemaVersion":1,
          "unexpected":true
        }
        """
        let transport = AuthorizationTestTransport(
            responses: [PasskeyBackupHTTPResponse(statusCode: 200, body: Data(response.utf8))]
        )
        let service = try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: transport,
            authorizationProvider: AuthorizationTestProvider(token: "test-token")
        )

        do {
            _ = try await service.assertionChallenge(storageKey: "wallet-1234")
            XCTFail("Unknown response field unexpectedly passed")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .malformedChallengeServiceResponse)
        }
    }

    func testChallengeClientRejectsNoncanonicalBaseURLAliases() {
        let rejected = [
            " https://backup.fearlesswallet.io",
            "https://backup.fearlesswallet.io ",
            "https://backup.fearlesswallet.io:443",
            "https://backup.fearlesswallet.io/api",
            "https://backup.fearlesswallet.io//",
            "https://BACKUP.fearlesswallet.io"
        ]

        for baseURL in rejected {
            XCTAssertThrowsError(
                try HTTPPasskeyBackupChallengeService(
                    baseURL: baseURL,
                    transport: AuthorizationTestTransport(responses: []),
                    authorizationProvider: AuthorizationTestProvider(token: "test-token")
                ),
                "Unexpectedly accepted base URL alias: \(baseURL)"
            )
        }
    }

    func testAssertionSerializerProducesRequiredWebAuthnResponseFields() throws {
        let userHandle = Data((0 ..< 32).map { UInt8($0) })
        let json = try PasskeyCredentialResponseSerializer.assertionJSON(
            credentialID: Data([0x01]),
            clientDataJSON: Data([0x02]),
            authenticatorData: Data([0x03]),
            signature: Data([0x04]),
            userHandle: userHandle
        )
        let credential = try jsonObject(json)
        let response = try XCTUnwrap(credential["response"] as? [String: Any])

        XCTAssertEqual(
            Set(response.keys),
            Set(["clientDataJSON", "authenticatorData", "signature", "userHandle"])
        )
        XCTAssertEqual(response["clientDataJSON"] as? String, "Ag")
        XCTAssertEqual(response["authenticatorData"] as? String, "Aw")
        XCTAssertEqual(response["signature"] as? String, "BA")
        XCTAssertEqual(response["userHandle"] as? String, base64URL(userHandle))
    }

    func testRegistrationSerializerRejectsEveryEmptyRequiredField() {
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.registrationJSON(
                credentialID: Data(),
                clientDataJSON: Data([1]),
                attestationObject: Data([2])
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.registrationJSON(
                credentialID: Data([1]),
                clientDataJSON: Data(),
                attestationObject: Data([2])
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.registrationJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                attestationObject: Data()
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.registrationJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                attestationObject: Data([3]),
                authenticatorData: Data()
            )
        }
    }

    func testAssertionSerializerRejectsEveryEmptyRequiredField() {
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: Data(),
                clientDataJSON: Data([1]),
                authenticatorData: Data([2]),
                signature: Data([3]),
                userHandle: Data(repeating: 4, count: 32)
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: Data([1]),
                clientDataJSON: Data(),
                authenticatorData: Data([2]),
                signature: Data([3]),
                userHandle: Data(repeating: 4, count: 32)
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                authenticatorData: Data(),
                signature: Data([3]),
                userHandle: Data(repeating: 4, count: 32)
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                authenticatorData: Data([3]),
                signature: Data(),
                userHandle: Data(repeating: 4, count: 32)
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                authenticatorData: Data([3]),
                signature: Data([4]),
                userHandle: Data()
            )
        }
    }

    func testSerializerRejectsFieldsBeyondChallengeServiceLimits() {
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.registrationJSON(
                credentialID: Data(repeating: 1, count: 385),
                clientDataJSON: Data([2]),
                attestationObject: Data([3])
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.registrationJSON(
                credentialID: Data([1]),
                clientDataJSON: Data(repeating: 2, count: 6145),
                attestationObject: Data([3])
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.registrationJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                attestationObject: Data(repeating: 3, count: 24577)
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                authenticatorData: Data([3]),
                signature: Data([4]),
                userHandle: Data(repeating: 5, count: 31)
            )
        }
        assertInvalidCredentialResponse {
            try PasskeyCredentialResponseSerializer.assertionJSON(
                credentialID: Data([1]),
                clientDataJSON: Data([2]),
                authenticatorData: Data([3]),
                signature: Data([4]),
                userHandle: Data(repeating: 5, count: 33)
            )
        }
    }

    func testSerializerAcceptsFieldsAtChallengeServiceLimits() throws {
        _ = try PasskeyCredentialResponseSerializer.registrationJSON(
            credentialID: Data(repeating: 1, count: 384),
            clientDataJSON: Data(repeating: 2, count: 6144),
            attestationObject: Data(repeating: 3, count: 24576),
            authenticatorData: Data(repeating: 4, count: 24576)
        )
        _ = try PasskeyCredentialResponseSerializer.assertionJSON(
            credentialID: Data(repeating: 1, count: 384),
            clientDataJSON: Data(repeating: 2, count: 6144),
            authenticatorData: Data(repeating: 3, count: 24576),
            signature: Data(repeating: 4, count: 24576),
            userHandle: Data(repeating: 5, count: 32)
        )
    }

    func testAES256GCMEnvelopeRoundTripsWithCanonicalHeaderAndRandomNonce() throws {
        let cryptography = AESGCMPasskeyBackupEnvelopeCryptography()
        let metadata = try envelopeMetadata()
        let key = Data((1 ... 32).map(UInt8.init))
        let plaintext = Data("recoverable wallet backup".utf8)

        let first = try cryptography.encrypt(plaintext, metadata: metadata, key: key)
        let second = try cryptography.encrypt(plaintext, metadata: metadata, key: key)

        XCTAssertEqual(first.prefix(8), Data("FPBKAEAD".utf8))
        XCTAssertEqual(first[8], 1)
        XCTAssertEqual(first[9], 1)
        XCTAssertEqual(first[10], 12)
        XCTAssertEqual(first[11], 16)
        XCTAssertNotEqual(first, second)
        XCTAssertNotEqual(first.subdata(in: 16 ..< 28), second.subdata(in: 16 ..< 28))
        XCTAssertEqual(try cryptography.decrypt(first, metadata: metadata, key: key), plaintext)
    }

    func testAES256GCMEnvelopeRejectsTamperingWrongKeyAndMetadataSwaps() throws {
        let cryptography = AESGCMPasskeyBackupEnvelopeCryptography()
        let metadata = try envelopeMetadata()
        let key = Data(repeating: 7, count: 32)
        let envelope = try cryptography.encrypt(Data([1, 2, 3]), metadata: metadata, key: key)

        for index in [16, 28, envelope.count - 1] {
            var tampered = envelope
            tampered[index] ^= 1
            XCTAssertThrowsError(try cryptography.decrypt(tampered, metadata: metadata, key: key))
        }
        XCTAssertThrowsError(
            try cryptography.decrypt(envelope, metadata: metadata, key: Data(repeating: 8, count: 32))
        )
        let swappedMetadata = [
            try envelopeMetadata(storageKey: "wallet-5678"),
            try envelopeMetadata(walletId: "wallet-9999"),
            try envelopeMetadata(accountName: "mallory@example.com"),
            try envelopeMetadata(createdAtMillis: 1_767_225_600_001)
        ]
        for swapped in swappedMetadata {
            XCTAssertThrowsError(try cryptography.decrypt(envelope, metadata: swapped, key: key))
        }
    }

    func testAES256GCMEnvelopeRejectsEveryTruncationExtensionBadHeaderAndKeySize() throws {
        let cryptography = AESGCMPasskeyBackupEnvelopeCryptography()
        let metadata = try envelopeMetadata()
        let key = Data(repeating: 9, count: 32)
        let envelope = try cryptography.encrypt(Data([1, 2, 3]), metadata: metadata, key: key)

        for length in 0 ..< envelope.count {
            XCTAssertThrowsError(try cryptography.validateCanonicalEnvelope(Data(envelope.prefix(length))))
        }
        var extended = envelope
        extended.append(0)
        XCTAssertThrowsError(try cryptography.validateCanonicalEnvelope(extended))
        for index in 0 ... 15 {
            var altered = envelope
            altered[index] ^= 1
            XCTAssertThrowsError(try cryptography.validateCanonicalEnvelope(altered))
        }
        for length in [0, 16, 31, 33, 64] {
            XCTAssertThrowsError(
                try cryptography.encrypt(Data([1]), metadata: metadata, key: Data(repeating: 1, count: length))
            )
        }
        let maximumPlaintext = Data(repeating: 0xA5, count: 256 * 1024 - 44)
        let maximumEnvelope = try cryptography.encrypt(
            maximumPlaintext,
            metadata: metadata,
            key: key
        )
        XCTAssertEqual(maximumEnvelope.count, 256 * 1024)
        XCTAssertEqual(
            try cryptography.decrypt(maximumEnvelope, metadata: metadata, key: key),
            maximumPlaintext
        )
    }

    func testDecryptsSharedCrossPlatformAESGCMContractVector() throws {
        let envelope = try PasskeyBackupContract.decodeBase64URL(
            "RlBCS0FFQUQBAQwQAAAAHQABAgMEBQYHCAkKCxJCbuS78BFnbl_ULhb12v1I5M7-G-ZXHqwrFsgsJiQcEPtBrkqPDXxWvxW4BQ"
        )

        XCTAssertEqual(
            try AESGCMPasskeyBackupEnvelopeCryptography().decrypt(
                envelope,
                metadata: envelopeMetadata(),
                key: Data((1 ... 32).map(UInt8.init))
            ),
            Data("cross-platform-passkey-backup".utf8)
        )
    }

    func testEncryptedRecordRejectsArbitraryNonemptyPayload() throws {
        XCTAssertThrowsError(
            try PasskeyBackupEncryptedRecord(
                storageKey: "wallet-1234",
                walletId: "wallet-001",
                accountName: "alice@example.com",
                createdAtMillis: 1_767_225_600_000,
                encryptedPayload: Data([1, 2, 3])
            )
        ) { error in
            XCTAssertEqual(error as? PasskeyBackupError, .invalidEncryptedEnvelope)
        }
    }

    func testCredentialLifecycleAuthorizesExactBodiesAndValidatesResponseShape() async throws {
        let credentialId = base64URL(Data("credential-1".utf8))
        let transport = AuthorizationTestTransport(
            responses: [
                httpJSON(
                    #"{"storageKey":"wallet-1234","credentials":[{"id":"\#(credentialId)","aaguid":"00000000-0000-0000-0000-000000000000","registrationPlatform":"ios","deviceType":"multiDevice","backedUp":true,"transports":["internal","hybrid"]}],"rpId":"fearlesswallet.io","schemaVersion":1}"#
                ),
                httpJSON(
                    #"{"storageKey":"wallet-1234","credentialId":"\#(credentialId)","remainingCredentials":0,"rpId":"fearlesswallet.io","schemaVersion":1}"#
                ),
                httpJSON(
                    #"{"storageKey":"wallet-1234","remainingCredentials":0,"rpId":"fearlesswallet.io","schemaVersion":1}"#
                )
            ]
        )
        let authorization = AuthorizationTestProvider(token: "test-token")
        let service = try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: transport,
            authorizationProvider: authorization
        )

        let listed = try await service.listCredentials(storageKey: "wallet-1234")
        let revoked = try await service.revokeCredential(
            storageKey: "wallet-1234",
            credentialId: credentialId
        )
        let revokedAll = try await service.revokeAllCredentials(storageKey: "wallet-1234")

        XCTAssertEqual(listed.credentials.map(\.id), [credentialId])
        XCTAssertEqual(listed.credentials.first?.transports, ["internal", "hybrid"])
        XCTAssertEqual(revoked.remainingCredentials, 0)
        XCTAssertNil(revokedAll.credentialId)
        XCTAssertEqual(
            authorization.requests.map(\.path),
            [
                PasskeyBackupAuthorizationRequest.credentialsListPath,
                PasskeyBackupAuthorizationRequest.credentialsRevokePath,
                PasskeyBackupAuthorizationRequest.credentialsRevokeAllPath
            ]
        )
        for (grant, request) in zip(authorization.requests, transport.requests) {
            let bodyData = try XCTUnwrap(request.body)
            XCTAssertEqual(grant.bodySha256, sha256Base64URL(bodyData))
            XCTAssertEqual(request.headers["Authorization"], "Bearer test-token")
            let body = try XCTUnwrap(
                JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            )
            var expectedKeys: Set<String> = ["storageKey", "rpId", "schemaVersion"]
            if grant.path == PasskeyBackupAuthorizationRequest.credentialsRevokePath {
                expectedKeys.insert("credentialId")
            }
            XCTAssertEqual(Set(body.keys), expectedKeys)
            XCTAssertEqual(body["storageKey"] as? String, "wallet-1234")
            XCTAssertEqual(body["rpId"] as? String, "fearlesswallet.io")
            XCTAssertEqual(body["schemaVersion"] as? Int, 1)
        }
    }

    func testCredentialLifecycleRejectsMalformedSummariesAndNonzeroRevokeAll() async throws {
        let credentialId = base64URL(Data("credential-1".utf8))
        let validSummary =
            #"{"id":"\#(credentialId)","aaguid":"00000000-0000-0000-0000-000000000000","registrationPlatform":"ios","deviceType":"multiDevice","backedUp":true}"#
        let malformedSummaries = [
            #"{"id":"\#(credentialId)","aaguid":"BAD","registrationPlatform":"ios","deviceType":"multiDevice","backedUp":true}"#,
            #"{"id":"\#(credentialId)","aaguid":"00000000-0000-0000-0000-000000000000","registrationPlatform":"web","deviceType":"multiDevice","backedUp":true}"#,
            #"{"id":"\#(credentialId)","aaguid":"00000000-0000-0000-0000-000000000000","registrationPlatform":"ios","deviceType":"singleDevice","backedUp":true}"#,
            #"{"id":"\#(credentialId)","aaguid":"00000000-0000-0000-0000-000000000000","registrationPlatform":"ios","deviceType":"multiDevice","backedUp":true,"transports":["internal","internal"]}"#
        ]

        for summary in malformedSummaries {
            let service = try lifecycleService(
                response: #"{"storageKey":"wallet-1234","credentials":[\#(summary)],"rpId":"fearlesswallet.io","schemaVersion":1}"#
            )
            do {
                _ = try await service.listCredentials(storageKey: "wallet-1234")
                XCTFail("Malformed credential summary unexpectedly passed: \(summary)")
            } catch {
                XCTAssertEqual(error as? PasskeyBackupError, .malformedChallengeServiceResponse)
            }
        }

        let oversizedCredentialList = (0 ... 32).map { index in
            let id = base64URL(Data("credential-\(index)".utf8))
            return #"{"id":"\#(id)","aaguid":"00000000-0000-0000-0000-000000000000","registrationPlatform":"ios","deviceType":"multiDevice","backedUp":true}"#
        }.joined(separator: ",")
        for credentials in ["\(validSummary),\(validSummary)", oversizedCredentialList] {
            let service = try lifecycleService(
                response: #"{"storageKey":"wallet-1234","credentials":[\#(credentials)],"rpId":"fearlesswallet.io","schemaVersion":1}"#
            )
            do {
                _ = try await service.listCredentials(storageKey: "wallet-1234")
                XCTFail("Invalid credential list unexpectedly passed")
            } catch {
                XCTAssertEqual(error as? PasskeyBackupError, .malformedChallengeServiceResponse)
            }
        }

        let service = try lifecycleService(
            response: #"{"storageKey":"wallet-1234","remainingCredentials":1,"rpId":"fearlesswallet.io","schemaVersion":1}"#
        )
        await assertThrowsAsync {
            _ = try await service.revokeAllCredentials(storageKey: "wallet-1234")
        }
    }

    func testDeleteRevokesServerCredentialsBeforeCloudAndPreservesCloudOnServerFailure() async throws {
        let envelope = try AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
            Data([1, 2, 3]),
            metadata: envelopeMetadata(),
            key: Data(repeating: 1, count: 32)
        )
        let record = try PasskeyBackupEncryptedRecord(
            storageKey: "wallet-1234",
            walletId: "wallet-001",
            accountName: "alice@example.com",
            createdAtMillis: 1_767_225_600_000,
            encryptedPayload: envelope
        )
        let cloud = LifecycleTestCloudStorage(record: record)
        let service = LifecycleTestChallengeService(revokeAllError: PasskeyBackupError.unavailableAuthorization)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            isReleaseEnabled: true
        )

        await assertThrowsAsync {
            try await workflow.deleteBackup(storageKey: "wallet-1234")
        }
        XCTAssertEqual(service.revokedAllStorageKey, "wallet-1234")
        XCTAssertNil(cloud.deletedStorageKey)
        let recoverableRecord = try await cloud.loadPasskeyBackup(storageKey: "wallet-1234")
        XCTAssertNotNil(recoverableRecord)
    }

    func testDeleteRemovesCloudOnlyAfterSuccessfulRevokeAll() async throws {
        let envelope = try AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
            Data([1]),
            metadata: envelopeMetadata(),
            key: Data(repeating: 1, count: 32)
        )
        let record = try PasskeyBackupEncryptedRecord(
            storageKey: "wallet-1234",
            walletId: "wallet-001",
            accountName: "alice@example.com",
            createdAtMillis: 1_767_225_600_000,
            encryptedPayload: envelope
        )
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(
            record: record,
            beforeDelete: {
                XCTAssertEqual(service.revokedAllStorageKey, "wallet-1234")
            }
        )
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            isReleaseEnabled: true
        )

        try await workflow.deleteBackup(storageKey: "wallet-1234")

        XCTAssertEqual(cloud.deletedStorageKey, "wallet-1234")
        let deletedRecord = try await cloud.loadPasskeyBackup(storageKey: "wallet-1234")
        XCTAssertNil(deletedRecord)
    }

    func testPlaintextWorkflowEncryptsAndDecryptsThroughRecoverableKeyProvider() async throws {
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let registrationChallenge = try PasskeyBackupRegistrationChallenge(
            registrationId: "registration-1234",
            challenge: Data(repeating: 1, count: 32),
            userId: Data(repeating: 2, count: 32),
            userName: "alice@example.com",
            displayName: "Alice",
            storageKey: "wallet-1234"
        )
        let pendingRegistration = try PendingPasskeyBackupRegistration(
            challenge: registrationChallenge,
            walletId: "wallet-001",
            accountName: "alice@example.com"
        )
        let plaintext = Data("wallet-secret-material".utf8)

        let saved = try await workflow.finishRegistrationWithPlaintext(
            pending: pendingRegistration,
            credentialResponseJSON: #"{"id":"Y3JlZGVudGlhbA"}"#,
            plaintextBackup: plaintext
        )
        let assertionChallenge = try PasskeyBackupAssertionChallenge(
            assertionId: "assertion-1234",
            challenge: Data(repeating: 3, count: 32),
            storageKey: "wallet-1234"
        )
        let restored = try await workflow.finishRestoreWithDecryption(
            pending: PendingPasskeyBackupAssertion(challenge: assertionChallenge),
            credentialResponseJSON: #"{"id":"Y3JlZGVudGlhbA"}"#
        )

        XCTAssertNotEqual(saved.encryptedPayload, plaintext)
        XCTAssertEqual(restored, plaintext)
    }

    func testPlaintextWorkflowFailsBeforeRegistrationWithoutRecoverableKeySource() async throws {
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let challenge = try PasskeyBackupRegistrationChallenge(
            registrationId: "registration-1234",
            challenge: Data(repeating: 1, count: 32),
            userId: Data(repeating: 2, count: 32),
            userName: "alice@example.com",
            displayName: "Alice",
            storageKey: "wallet-1234"
        )
        let pending = try PendingPasskeyBackupRegistration(
            challenge: challenge,
            walletId: "wallet-001",
            accountName: "alice@example.com"
        )

        await assertThrowsAsync {
            _ = try await workflow.finishRegistrationWithPlaintext(
                pending: pending,
                credentialResponseJSON: #"{"id":"Y3JlZGVudGlhbA"}"#,
                plaintextBackup: Data([1])
            )
        }
        XCTAssertNil(service.completedRegistrationId)
        let missingRecord = try await cloud.loadPasskeyBackup(storageKey: "wallet-1234")
        XCTAssertNil(missingRecord)
    }

    func testCloudSaveFailureRevokesOnlyNewlyRegisteredCredential() async throws {
        let credentialId = base64URL(Data("credential-1".utf8))
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(
            record: nil,
            saveError: PasskeyBackupError.unavailableCloudStorage
        )
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let challenge = try PasskeyBackupRegistrationChallenge(
            registrationId: "registration-1234",
            challenge: Data(repeating: 1, count: 32),
            userId: Data(repeating: 2, count: 32),
            userName: "alice@example.com",
            displayName: "Alice",
            storageKey: "wallet-1234"
        )
        let pending = try PendingPasskeyBackupRegistration(
            challenge: challenge,
            walletId: "wallet-001",
            accountName: "alice@example.com"
        )

        await assertThrowsAsync {
            _ = try await workflow.finishRegistrationWithPlaintext(
                pending: pending,
                credentialResponseJSON: #"{"id":"\#(credentialId)"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
        }
        XCTAssertEqual(service.completedRegistrationId, "registration-1234")
        XCTAssertEqual(service.revokedCredentialStorageKey, "wallet-1234")
        XCTAssertEqual(service.revokedCredentialId, credentialId)
        XCTAssertNil(service.revokedAllStorageKey)
    }

    func testLegacyRawRegistrationFailsClosedBeforeClockOrCeremonyWithoutExplicitMetadata() async throws {
        var clockCalls = 0
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            isReleaseEnabled: true,
            createdAtMillisProvider: {
                clockCalls += 1
                return 1_767_225_600_000
            }
        )
        let envelope = try AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
            Data([1]),
            metadata: envelopeMetadata(),
            key: Data((1 ... 32).map(UInt8.init))
        )

        do {
            _ = try await workflow.finishRegistration(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
                encryptedPayload: envelope
            )
            XCTFail("Legacy raw registration unexpectedly passed")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .encryptedPayloadMetadataRequired)
        }
        XCTAssertEqual(clockCalls, 0)
        XCTAssertNil(service.completedRegistrationId)
        XCTAssertNil(service.revokedCredentialId)
    }

    func testPreEncryptedRegistrationUsesCallerAuthenticatedTimestampWithoutConsultingWorkflowClock() async throws {
        let callerCreatedAtMillis: Int64 = 1_767_225_612_345
        var clockCalls = 0
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: {
                clockCalls += 1
                return 1_767_225_699_999
            }
        )
        let envelope = try AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
            Data([1]),
            metadata: envelopeMetadata(createdAtMillis: callerCreatedAtMillis),
            key: Data((1 ... 32).map(UInt8.init))
        )
        let record = try PasskeyBackupEncryptedRecord(
            storageKey: "wallet-1234",
            walletId: "wallet-001",
            accountName: "alice@example.com",
            createdAtMillis: callerCreatedAtMillis,
            encryptedPayload: envelope
        )

        let saved = try await workflow.finishRegistrationWithEncryptedRecord(
            pending: self.pendingRegistration(),
            credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
            record: record
        )

        XCTAssertEqual(saved.createdAtMillis, callerCreatedAtMillis)
        let stored = try await cloud.loadPasskeyBackup(storageKey: "wallet-1234")
        XCTAssertEqual(stored?.createdAtMillis, callerCreatedAtMillis)
        XCTAssertEqual(clockCalls, 0)
        XCTAssertEqual(service.completedRegistrationId, "registration-1234")
    }

    func testPreEncryptedRegistrationRejectsCreatedAtAADMismatchBeforeCeremony() async throws {
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let envelope = try AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
            Data([1]),
            metadata: envelopeMetadata(),
            key: Data((1 ... 32).map(UInt8.init))
        )
        let mismatchedRecord = try PasskeyBackupEncryptedRecord(
            storageKey: "wallet-1234",
            walletId: "wallet-001",
            accountName: "alice@example.com",
            createdAtMillis: 1_767_225_600_001,
            encryptedPayload: envelope
        )

        do {
            _ = try await workflow.finishRegistrationWithEncryptedRecord(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
                record: mismatchedRecord
            )
            XCTFail("Record with mismatched createdAt AAD unexpectedly passed")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .envelopeAuthenticationFailed)
        }
        XCTAssertNil(service.completedRegistrationId)
        XCTAssertNil(service.revokedCredentialId)
        let missingRecord = try await cloud.loadPasskeyBackup(storageKey: "wallet-1234")
        XCTAssertNil(missingRecord)
    }

    func testPreEncryptedRegistrationRejectsRecordIdentityMismatchBeforeCeremony() async throws {
        let service = LifecycleTestChallengeService()
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true
        )
        let identities: [(String, String, String, PasskeyBackupError)] = [
            ("wallet-9999", "wallet-001", "alice@example.com", .mismatchedChallengeStorageKey),
            ("wallet-1234", "wallet-999", "alice@example.com", .invalidWalletId),
            ("wallet-1234", "wallet-001", "mallory@example.com", .invalidUserName)
        ]

        for (storageKey, walletId, accountName, expectedError) in identities {
            let metadata = try envelopeMetadata(
                storageKey: storageKey,
                walletId: walletId,
                accountName: accountName
            )
            let envelope = try AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
                Data([1]),
                metadata: metadata,
                key: Data((1 ... 32).map(UInt8.init))
            )
            let record = try PasskeyBackupEncryptedRecord(
                storageKey: storageKey,
                walletId: walletId,
                accountName: accountName,
                createdAtMillis: metadata.createdAtMillis,
                encryptedPayload: envelope
            )
            do {
                _ = try await workflow.finishRegistrationWithEncryptedRecord(
                    pending: self.pendingRegistration(),
                    credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
                    record: record
                )
                XCTFail("Mismatched encrypted record identity unexpectedly passed")
            } catch {
                XCTAssertEqual(error as? PasskeyBackupError, expectedError)
            }
        }

        XCTAssertNil(service.completedRegistrationId)
        XCTAssertNil(service.revokedCredentialId)
        let missingRecord = try await cloud.loadPasskeyBackup(storageKey: "wallet-1234")
        XCTAssertNil(missingRecord)
    }

    func testPreEncryptedRegistrationCompensatesStorageMismatchAfterCompletion() async throws {
        let credentialId = "Y3JlZC0x"
        let service = LifecycleTestChallengeService(registrationStorageKey: "wallet-5678")
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let envelope = try AESGCMPasskeyBackupEnvelopeCryptography().encrypt(
            Data([1]),
            metadata: envelopeMetadata(),
            key: Data((1 ... 32).map(UInt8.init))
        )
        let record = try PasskeyBackupEncryptedRecord(
            storageKey: "wallet-1234",
            walletId: "wallet-001",
            accountName: "alice@example.com",
            createdAtMillis: 1_767_225_600_000,
            encryptedPayload: envelope
        )

        await assertThrowsAsync {
            _ = try await workflow.finishRegistrationWithEncryptedRecord(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"\#(credentialId)"}"#,
                record: record
            )
        }
        XCTAssertEqual(service.completedRegistrationId, "registration-1234")
        XCTAssertEqual(service.revokedCredentialStorageKey, "wallet-1234")
        XCTAssertEqual(service.revokedCredentialId, credentialId)
        XCTAssertNil(service.revokedAllStorageKey)
    }

    func testRegistrationResponseLossAfterServerCommitStillRevokesCredential() async throws {
        let credentialId = "Y3JlZC0x"
        let service = LifecycleTestChallengeService(
            completeRegistrationError: PasskeyBackupError.registrationCompletionOutcomeUnknown
        )
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )

        await assertThrowsAsync {
            _ = try await workflow.finishRegistrationWithPlaintext(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"\#(credentialId)"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
        }
        XCTAssertEqual(service.completedRegistrationId, "registration-1234")
        XCTAssertEqual(service.revokedCredentialStorageKey, "wallet-1234")
        XCTAssertEqual(service.revokedCredentialId, credentialId)
        let missingRecord = try await cloud.loadPasskeyBackup(storageKey: "wallet-1234")
        XCTAssertNil(missingRecord)
    }

    func testRegistrationCompensationPropagatesRevokeFailureWithoutMaskingPrimaryError() async throws {
        let service = LifecycleTestChallengeService(
            revokeCredentialError: PasskeyBackupError.unavailableAuthorization,
            completeRegistrationError: PasskeyBackupError.registrationCompletionOutcomeUnknown
        )
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: LifecycleTestCloudStorage(record: nil),
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )

        do {
            _ = try await workflow.finishRegistrationWithPlaintext(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
            XCTFail("Registration with failed revoke compensation unexpectedly passed")
        } catch {
            let compensationError = try XCTUnwrap(
                error as? PasskeyBackupRegistrationCompensationError
            )
            XCTAssertEqual(
                compensationError.primaryError as? PasskeyBackupError,
                .registrationCompletionOutcomeUnknown
            )
            XCTAssertEqual(compensationError.failureKind, .revokeFailed)
            XCTAssertEqual(
                compensationError.cleanupError as? PasskeyBackupError,
                .unavailableAuthorization
            )
        }
        XCTAssertEqual(service.revokedCredentialStorageKey, "wallet-1234")
        XCTAssertEqual(service.revokedCredentialId, "Y3JlZC0x")
    }

    func testExplicitRegistrationRejectionDoesNotRevokeExistingCredentialId() async throws {
        let service = LifecycleTestChallengeService(
            completeRegistrationError: PasskeyBackupError.challengeServiceHTTPStatus(409)
        )
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: LifecycleTestCloudStorage(record: nil),
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )

        await assertThrowsAsync {
            _ = try await workflow.finishRegistrationWithPlaintext(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
        }
        XCTAssertEqual(service.completedRegistrationId, "registration-1234")
        XCTAssertNil(service.revokedCredentialStorageKey)
        XCTAssertNil(service.revokedCredentialId)
    }

    func testCancellationWhileRegistrationCompletionIsInFlightStillRevokesCredential() async throws {
        let credentialId = "Y3JlZC0x"
        let completionGate = CancellationCompletionGate()
        let service = AdversarialCompensationChallengeService(completionGate: completionGate)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: LifecycleTestCloudStorage(record: nil),
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            compensationTimeoutNanoseconds: 1_000_000_000,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let registrationTask = Task {
            try await workflow.finishRegistrationWithPlaintext(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"\#(credentialId)"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
        }

        await completionGate.waitUntilCompletionStarted()
        registrationTask.cancel()
        await completionGate.releaseCompletion()
        do {
            _ = try await registrationTask.value
            XCTFail("Cancelled registration completion unexpectedly succeeded")
        } catch {
            XCTAssertTrue(
                error is CancellationError ||
                    error as? PasskeyBackupError == .registrationCompletionOutcomeUnknown
            )
        }
        let revocation = await service.revocationSnapshot()
        XCTAssertEqual(revocation.storageKey, "wallet-1234")
        XCTAssertEqual(revocation.credentialId, credentialId)
        XCTAssertEqual(revocation.observedCancellation, false)
    }

    func testPlaintextRegistrationCompensatesStorageMismatchAfterCompletion() async throws {
        let credentialId = "Y3JlZC0x"
        let service = LifecycleTestChallengeService(registrationStorageKey: "wallet-5678")
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )

        await assertThrowsAsync {
            _ = try await workflow.finishRegistrationWithPlaintext(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"\#(credentialId)"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
        }
        XCTAssertEqual(service.completedRegistrationId, "registration-1234")
        XCTAssertEqual(service.revokedCredentialStorageKey, "wallet-1234")
        XCTAssertEqual(service.revokedCredentialId, credentialId)
    }

    func testWorkflowRejectsMismatchedLifecycleResponseIdentities() async throws {
        let credentialId = "Y3JlZC0x"
        let otherCredentialId = "Y3JlZC0y"
        let listResult = try PasskeyBackupCredentialListResult(
            storageKey: "wallet-5678",
            credentials: []
        )
        let revokeStorageResult = try PasskeyBackupCredentialRevokeResult(
            storageKey: "wallet-5678",
            credentialId: credentialId,
            remainingCredentials: 0
        )
        let revokeCredentialResult = try PasskeyBackupCredentialRevokeResult(
            storageKey: "wallet-1234",
            credentialId: otherCredentialId,
            remainingCredentials: 0
        )
        let listWorkflow = try PasskeyBackupWorkflow(
            challengeService: LifecycleTestChallengeService(credentialListResult: listResult),
            cloudStorage: LifecycleTestCloudStorage(record: nil),
            isReleaseEnabled: true
        )
        let revokeStorageWorkflow = try PasskeyBackupWorkflow(
            challengeService: LifecycleTestChallengeService(
                revokeCredentialResult: revokeStorageResult
            ),
            cloudStorage: LifecycleTestCloudStorage(record: nil),
            isReleaseEnabled: true
        )
        let revokeCredentialWorkflow = try PasskeyBackupWorkflow(
            challengeService: LifecycleTestChallengeService(
                revokeCredentialResult: revokeCredentialResult
            ),
            cloudStorage: LifecycleTestCloudStorage(record: nil),
            isReleaseEnabled: true
        )

        await assertThrowsAsync {
            _ = try await listWorkflow.listCredentials(storageKey: "wallet-1234")
        }
        await assertThrowsAsync {
            _ = try await revokeStorageWorkflow.revokeCredential(
                storageKey: "wallet-1234",
                credentialId: credentialId
            )
        }
        await assertThrowsAsync {
            _ = try await revokeCredentialWorkflow.revokeCredential(
                storageKey: "wallet-1234",
                credentialId: credentialId
            )
        }
    }

    func testCancellationAfterRegistrationGetsIndependentCompensationOpportunity() async throws {
        let credentialId = "Y3JlZC0x"
        let saveGate = CancellationSaveGate()
        let service = AdversarialCompensationChallengeService()
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: CancellationGateCloudStorage(gate: saveGate),
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            compensationTimeoutNanoseconds: 1_000_000_000,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let registrationTask = Task {
            try await workflow.finishRegistrationWithPlaintext(
                pending: self.pendingRegistration(),
                credentialResponseJSON: #"{"id":"\#(credentialId)"}"#,
                plaintextBackup: Data([1, 2, 3])
            )
        }

        await saveGate.waitUntilSaveStarted()
        registrationTask.cancel()
        await saveGate.releaseSave()

        do {
            _ = try await registrationTask.value
            XCTFail("Cancelled registration unexpectedly succeeded")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let revocation = await service.revocationSnapshot()
        XCTAssertEqual(revocation.storageKey, "wallet-1234")
        XCTAssertEqual(revocation.credentialId, credentialId)
        XCTAssertEqual(revocation.observedCancellation, false)
    }

    func testRegistrationCompensationTimeoutIsObservableWithoutMaskingPrimaryError() async throws {
        let revokeGate = BlockingRevokeGate()
        let service = AdversarialCompensationChallengeService(revokeGate: revokeGate)
        let completion = CompensationCompletionProbe()
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: LifecycleTestCloudStorage(
                record: nil,
                saveError: PasskeyBackupError.unavailableCloudStorage
            ),
            backupKeyProvider: FixedTestBackupKeyProvider(),
            isReleaseEnabled: true,
            compensationTimeoutNanoseconds: 20_000_000,
            createdAtMillisProvider: { 1_767_225_600_000 }
        )
        let registrationTask = Task {
            do {
                _ = try await workflow.finishRegistrationWithPlaintext(
                    pending: self.pendingRegistration(),
                    credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
                    plaintextBackup: Data([1, 2, 3])
                )
                await completion.record(didPreserveOriginalError: false)
            } catch {
                let compensationError = error as? PasskeyBackupRegistrationCompensationError
                let preservedPrimaryAndTimeout =
                    (compensationError?.primaryError as? PasskeyBackupError) ==
                        .unavailableCloudStorage &&
                        compensationError?.failureKind == .timedOut &&
                        compensationError?.cleanupError == nil
                await completion.record(didPreserveOriginalError: preservedPrimaryAndTimeout)
            }
        }

        await revokeGate.waitUntilRevokeStarted()
        try await Task.sleep(nanoseconds: 100_000_000)
        let boundedResult = await completion.snapshot()
        XCTAssertTrue(boundedResult.isFinished)
        XCTAssertTrue(boundedResult.didPreserveOriginalError)

        await revokeGate.releaseRevoke()
        await registrationTask.value
    }

    func testWorkflowRejectsInvalidCompensationTimeouts() {
        for timeout in [UInt64(0), 999_999, 30_000_000_001] {
            XCTAssertThrowsError(
                try PasskeyBackupWorkflow(
                    challengeService: LifecycleTestChallengeService(),
                    cloudStorage: LifecycleTestCloudStorage(record: nil),
                    isReleaseEnabled: true,
                    compensationTimeoutNanoseconds: timeout
                )
            ) { error in
                XCTAssertEqual(error as? PasskeyBackupError, .invalidCompensationTimeout)
            }
        }
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportRejectsInvalidResponseLimits() {
        for limit in [0, -1, PasskeyBackupHTTPTransportPolicy.maximumResponseBytes + 1] {
            XCTAssertThrowsError(
                try URLSessionPasskeyBackupHTTPTransport(maximumResponseBytes: limit)
            ) { error in
                XCTAssertEqual(error as? PasskeyBackupError, .invalidResponseSizeLimit)
            }
        }
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportRejectsOversizedDeclaredResponseBeforeBody() async throws {
        PasskeyBackupMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Length": "9"]
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            // Finish without a body so URLProtocol delivers the declared
            // length to the session delegate instead of leaving a stalled
            // mock request that can only prove the timeout policy.
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { PasskeyBackupMockURLProtocol.reset() }

        let transport = try URLSessionPasskeyBackupHTTPTransport(
            configuration: passkeyMockConfiguration(),
            maximumResponseBytes: 8
        )
        do {
            _ = try await transport.execute(passkeyTransportRequest())
            XCTFail("Oversized declared response unexpectedly passed")
        } catch {
            XCTAssertEqual(
                error as? PasskeyBackupError,
                .challengeServiceResponseTooLarge
            )
        }
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportRejectsChunkedResponseBeyondLimit() async throws {
        PasskeyBackupMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didLoad: Data(repeating: 0x41, count: 8)
            )
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didLoad: Data([0x42])
            )
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { PasskeyBackupMockURLProtocol.reset() }

        let transport = try URLSessionPasskeyBackupHTTPTransport(
            configuration: passkeyMockConfiguration(),
            maximumResponseBytes: 8
        )
        do {
            _ = try await transport.execute(passkeyTransportRequest())
            XCTFail("Oversized streamed response unexpectedly passed")
        } catch {
            XCTAssertEqual(
                error as? PasskeyBackupError,
                .challengeServiceResponseTooLarge
            )
        }
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportBoundsDecodedStreamingBytes() async throws {
        PasskeyBackupMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: [
                    "Content-Encoding": "gzip",
                    "Transfer-Encoding": "chunked"
                ]
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            // URLSession delegates observe decoded body chunks. Simulate a
            // tiny compressed entity expanding beyond the configured bound.
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didLoad: Data(repeating: 0x41, count: 9)
            )
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { PasskeyBackupMockURLProtocol.reset() }

        let transport = try URLSessionPasskeyBackupHTTPTransport(
            configuration: passkeyMockConfiguration(),
            maximumResponseBytes: 8
        )
        do {
            _ = try await transport.execute(passkeyTransportRequest())
            XCTFail("Expanded compressed response unexpectedly passed")
        } catch {
            XCTAssertEqual(
                error as? PasskeyBackupError,
                .challengeServiceResponseTooLarge
            )
        }
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportAcceptsResponseAtExactLimit() async throws {
        let expectedBody = Data(repeating: 0x41, count: 8)
        PasskeyBackupMockURLProtocol.install { protocolInstance, request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Length": "8"]
            )!
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocol(protocolInstance, didLoad: expectedBody)
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { PasskeyBackupMockURLProtocol.reset() }

        let transport = try URLSessionPasskeyBackupHTTPTransport(
            configuration: passkeyMockConfiguration(),
            maximumResponseBytes: expectedBody.count
        )
        let response = try await transport.execute(passkeyTransportRequest())

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.body, expectedBody)
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportCancellationStopsTaskAndClearsState() async throws {
        let started = expectation(description: "request started")
        let stopped = expectation(description: "URL loading stopped")
        PasskeyBackupMockURLProtocol.install(
            { protocolInstance, request in
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil
                )!
                protocolInstance.client?.urlProtocol(
                    protocolInstance,
                    didReceive: response,
                    cacheStoragePolicy: .notAllowed
                )
                started.fulfill()
            },
            onStop: { stopped.fulfill() }
        )
        defer { PasskeyBackupMockURLProtocol.reset() }

        let transport = try URLSessionPasskeyBackupHTTPTransport(
            configuration: passkeyMockConfiguration()
        )
        let requestTask = Task {
            try await transport.execute(passkeyTransportRequest())
        }

        await fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(transport.inFlightRequestCount, 1)
        requestTask.cancel()
        do {
            _ = try await requestTask.value
            XCTFail("Cancelled transport request unexpectedly passed")
        } catch is CancellationError {
            // The transport deliberately preserves structured-concurrency cancellation.
        } catch {
            XCTFail("Unexpected cancellation error: \(error)")
        }
        await fulfillment(of: [stopped], timeout: 1)
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportFailureClearsStateAndRedirectPolicyFailsClosed() async throws {
        PasskeyBackupMockURLProtocol.install { protocolInstance, _ in
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didFailWithError: URLError(.networkConnectionLost)
            )
        }
        defer { PasskeyBackupMockURLProtocol.reset() }

        let transport = try URLSessionPasskeyBackupHTTPTransport(
            configuration: passkeyMockConfiguration()
        )
        do {
            _ = try await transport.execute(passkeyTransportRequest())
            XCTFail("Network failure unexpectedly passed")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .networkConnectionLost)
        } catch {
            XCTFail("Unexpected network error: \(error)")
        }

        let hostileRedirect = URLRequest(url: URL(string: "https://attacker.example/capture")!)
        XCTAssertNil(PasskeyBackupBoundedSessionDelegate.redirectedRequest(hostileRedirect))
        XCTAssertFalse(PasskeyBackupHTTPTransportPolicy.followsRedirects)
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    @available(iOS 15.0, *)
    func testURLSessionTransportRejectsNonHTTPResponsesAndClearsState() async throws {
        PasskeyBackupMockURLProtocol.install { protocolInstance, request in
            let response = URLResponse(
                url: request.url!,
                mimeType: "application/json",
                expectedContentLength: 2,
                textEncodingName: "utf-8"
            )
            protocolInstance.client?.urlProtocol(
                protocolInstance,
                didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            protocolInstance.client?.urlProtocol(protocolInstance, didLoad: Data("{}".utf8))
            protocolInstance.client?.urlProtocolDidFinishLoading(protocolInstance)
        }
        defer { PasskeyBackupMockURLProtocol.reset() }

        let transport = try URLSessionPasskeyBackupHTTPTransport(
            configuration: passkeyMockConfiguration()
        )
        do {
            _ = try await transport.execute(passkeyTransportRequest())
            XCTFail("Non-HTTP response unexpectedly passed")
        } catch {
            XCTAssertEqual(error as? PasskeyBackupError, .malformedChallengeServiceResponse)
        }
        XCTAssertEqual(transport.inFlightRequestCount, 0)
    }

    func testRegistrationCompensationRejectsMismatchedRevokeResultIdentities() async throws {
        let credentialId = "Y3JlZC0x"
        let mismatchedResults = [
            try PasskeyBackupCredentialRevokeResult(
                storageKey: "wallet-5678",
                credentialId: credentialId,
                remainingCredentials: 0
            ),
            try PasskeyBackupCredentialRevokeResult(
                storageKey: "wallet-1234",
                credentialId: "Y3JlZC0y",
                remainingCredentials: 0
            ),
            try PasskeyBackupCredentialRevokeResult(
                storageKey: "wallet-1234",
                credentialId: nil,
                remainingCredentials: 0
            )
        ]

        for result in mismatchedResults {
            let service = LifecycleTestChallengeService(revokeCredentialResult: result)
            let workflow = try PasskeyBackupWorkflow(
                challengeService: service,
                cloudStorage: LifecycleTestCloudStorage(
                    record: nil,
                    saveError: PasskeyBackupError.unavailableCloudStorage
                ),
                backupKeyProvider: FixedTestBackupKeyProvider(),
                isReleaseEnabled: true,
                createdAtMillisProvider: { 1_767_225_600_000 }
            )

            do {
                _ = try await workflow.finishRegistrationWithPlaintext(
                    pending: pendingRegistration(),
                    credentialResponseJSON: #"{"id":"Y3JlZC0x"}"#,
                    plaintextBackup: Data([1, 2, 3])
                )
                XCTFail("Mismatched compensation result unexpectedly passed")
            } catch {
                let compensationError = try XCTUnwrap(
                    error as? PasskeyBackupRegistrationCompensationError
                )
                XCTAssertEqual(
                    compensationError.primaryError as? PasskeyBackupError,
                    .unavailableCloudStorage
                )
                XCTAssertEqual(compensationError.failureKind, .revokeFailed)
                XCTAssertEqual(
                    compensationError.cleanupError as? PasskeyBackupError,
                    .malformedChallengeServiceResponse
                )
            }
        }
    }

    func testWorkflowRejectsRevokeAllResultContainingCredentialIdentity() async throws {
        let injectedResult = try PasskeyBackupCredentialRevokeResult(
            storageKey: "wallet-1234",
            credentialId: "Y3JlZC0x",
            remainingCredentials: 0
        )
        let service = LifecycleTestChallengeService(revokeAllResult: injectedResult)
        let cloud = LifecycleTestCloudStorage(record: nil)
        let workflow = try PasskeyBackupWorkflow(
            challengeService: service,
            cloudStorage: cloud,
            isReleaseEnabled: true
        )

        await assertThrowsAsync {
            try await workflow.deleteBackup(storageKey: "wallet-1234")
        }
        XCTAssertNil(cloud.deletedStorageKey)
    }

    @MainActor
    @available(iOS 15.0, *)
    func testCoordinatorRejectsRevokeAllResultContainingCredentialIdentity() async throws {
        let injectedResult = try PasskeyBackupCredentialRevokeResult(
            storageKey: "wallet-1234",
            credentialId: "Y3JlZC0x",
            remainingCredentials: 0
        )
        let service = LifecycleTestChallengeService(revokeAllResult: injectedResult)
        let cloud = LifecycleTestCloudStorage(record: nil)
        let coordinator = try PasskeyBackupCoordinator(
            cloudStorage: cloud,
            challengeService: service,
            isReleaseEnabled: true
        )

        await assertThrowsAsync {
            try await coordinator.deleteEncryptedCloudBackup(storageKey: "wallet-1234")
        }
        XCTAssertNil(cloud.deletedStorageKey)
    }

    @MainActor
    @available(iOS 15.0, *)
    func testNativeAuthorizationControllerExecutorFailsClosedBehindReleaseFlag() async throws {
        let executor = try ASPasskeyBackupCeremonyExecutor(
            isReleaseEnabled: false,
            presentationAnchorProvider: { ASPresentationAnchor() }
        )
        let challenge = try PasskeyBackupRegistrationChallenge(
            registrationId: "registration-1234",
            challenge: Data(repeating: 1, count: 32),
            userId: Data(repeating: 2, count: 32),
            userName: "alice@example.com",
            displayName: "Alice",
            storageKey: "wallet-1234"
        )
        let pending = try PendingPasskeyBackupRegistration(
            challenge: challenge,
            walletId: "wallet-001",
            accountName: "alice@example.com"
        )

        await assertThrowsAsync {
            _ = try await executor.performRegistration(pending)
        }
    }

    private func envelopeMetadata(
        storageKey: String = "wallet-1234",
        walletId: String = "wallet-001",
        accountName: String = "alice@example.com",
        createdAtMillis: Int64 = 1_767_225_600_000
    ) throws -> PasskeyBackupEnvelopeMetadata {
        try PasskeyBackupEnvelopeMetadata(
            storageKey: storageKey,
            walletId: walletId,
            accountName: accountName,
            createdAtMillis: createdAtMillis
        )
    }

    private func pendingRegistration(
        storageKey: String = "wallet-1234"
    ) throws -> PendingPasskeyBackupRegistration {
        let challenge = try PasskeyBackupRegistrationChallenge(
            registrationId: "registration-1234",
            challenge: Data(repeating: 1, count: 32),
            userId: Data(repeating: 2, count: 32),
            userName: "alice@example.com",
            displayName: "Alice",
            storageKey: storageKey
        )
        return try PendingPasskeyBackupRegistration(
            challenge: challenge,
            walletId: "wallet-001",
            accountName: "alice@example.com"
        )
    }

    private func httpJSON(_ json: String) -> PasskeyBackupHTTPResponse {
        PasskeyBackupHTTPResponse(statusCode: 200, body: Data(json.utf8))
    }

    private func lifecycleService(response: String) throws -> HTTPPasskeyBackupChallengeService {
        try HTTPPasskeyBackupChallengeService(
            baseURL: "https://backup.fearlesswallet.io",
            transport: AuthorizationTestTransport(responses: [httpJSON(response)]),
            authorizationProvider: AuthorizationTestProvider(token: "test-token")
        )
    }

    private func assertThrowsAsync(
        _ operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected async operation to throw", file: file, line: line)
        } catch {}
    }

    private func jsonObject(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )
    }

    private func assertInvalidCredentialResponse(
        _ expression: () throws -> String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) { error in
            XCTAssertEqual(
                error as? PasskeyBackupError,
                .invalidCredentialResponse,
                file: file,
                line: line
            )
        }
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func sha256Base64URL(_ data: Data) -> String {
        base64URL(Data(SHA256.hash(data: data)))
    }

    @available(iOS 15.0, *)
    private func passkeyMockConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PasskeyBackupMockURLProtocol.self]
        return configuration
    }

    private func passkeyTransportRequest() -> PasskeyBackupHTTPRequest {
        PasskeyBackupHTTPRequest(
            method: "POST",
            url: URL(string: "https://backup.fearlesswallet.io/test")!,
            headers: ["Authorization": "Bearer test-token"],
            body: Data("{}".utf8)
        )
    }
}

private final class AuthorizationTestProvider: PasskeyBackupAuthorizationProvider {
    private let token: String
    private(set) var requests: [PasskeyBackupAuthorizationRequest] = []

    init(token: String) {
        self.token = token
    }

    func authorizationToken(for request: PasskeyBackupAuthorizationRequest) async throws -> String {
        requests.append(request)
        return token
    }
}

private final class AuthorizationTestTransport: PasskeyBackupHTTPTransport {
    private var responses: [PasskeyBackupHTTPResponse]
    private(set) var requests: [PasskeyBackupHTTPRequest] = []

    init(responses: [PasskeyBackupHTTPResponse]) {
        self.responses = responses
    }

    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        return responses.removeFirst()
    }
}

private final class PasskeyBackupMockURLProtocol: URLProtocol {
    typealias Handler = (PasskeyBackupMockURLProtocol, URLRequest) -> Void

    private static let lock = NSLock()
    private static var handler: Handler?
    private static var onStop: (() -> Void)?

    static func install(
        _ handler: @escaping Handler,
        onStop: (() -> Void)? = nil
    ) {
        lock.lock()
        self.handler = handler
        self.onStop = onStop
        lock.unlock()
    }

    static func reset() {
        lock.lock()
        handler = nil
        onStop = nil
        lock.unlock()
    }

    override class func canInit(with _: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        let handler = Self.handler
        Self.lock.unlock()
        guard let handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        handler(self, request)
    }

    override func stopLoading() {
        Self.lock.lock()
        let onStop = Self.onStop
        Self.lock.unlock()
        onStop?()
    }
}

private final class LifecycleTestChallengeService: PasskeyBackupChallengeService {
    private let revokeAllError: Error?
    private let revokeCredentialError: Error?
    private let completeRegistrationError: Error?
    private let registrationStorageKey: String
    private let credentialListResult: PasskeyBackupCredentialListResult?
    private let revokeCredentialResult: PasskeyBackupCredentialRevokeResult?
    private let revokeAllResult: PasskeyBackupCredentialRevokeResult?
    private(set) var revokedAllStorageKey: String?
    private(set) var completedRegistrationId: String?
    private(set) var completedAssertionId: String?
    private(set) var revokedCredentialStorageKey: String?
    private(set) var revokedCredentialId: String?

    init(
        revokeAllError: Error? = nil,
        revokeCredentialError: Error? = nil,
        completeRegistrationError: Error? = nil,
        registrationStorageKey: String = "wallet-1234",
        credentialListResult: PasskeyBackupCredentialListResult? = nil,
        revokeCredentialResult: PasskeyBackupCredentialRevokeResult? = nil,
        revokeAllResult: PasskeyBackupCredentialRevokeResult? = nil
    ) {
        self.revokeAllError = revokeAllError
        self.revokeCredentialError = revokeCredentialError
        self.completeRegistrationError = completeRegistrationError
        self.registrationStorageKey = registrationStorageKey
        self.credentialListResult = credentialListResult
        self.revokeCredentialResult = revokeCredentialResult
        self.revokeAllResult = revokeAllResult
    }

    func registrationChallenge(
        walletId _: String,
        accountName _: String,
        displayName _: String
    ) async throws -> PasskeyBackupRegistrationChallenge {
        throw PasskeyBackupError.malformedChallengeServiceResponse
    }

    func completeRegistration(
        registrationId: String,
        credentialResponseJSON _: String
    ) async throws -> PasskeyBackupChallengeResult {
        completedRegistrationId = registrationId
        if let completeRegistrationError {
            throw completeRegistrationError
        }
        return try PasskeyBackupChallengeResult(storageKey: registrationStorageKey)
    }

    func assertionChallenge(storageKey _: String) async throws -> PasskeyBackupAssertionChallenge {
        throw PasskeyBackupError.malformedChallengeServiceResponse
    }

    func completeAssertion(
        assertionId: String,
        credentialResponseJSON _: String
    ) async throws -> PasskeyBackupChallengeResult {
        completedAssertionId = assertionId
        return try PasskeyBackupChallengeResult(storageKey: "wallet-1234")
    }

    func revokeAllCredentials(storageKey: String) async throws -> PasskeyBackupCredentialRevokeResult {
        revokedAllStorageKey = storageKey
        if let revokeAllError {
            throw revokeAllError
        }
        if let revokeAllResult {
            return revokeAllResult
        }
        return try PasskeyBackupCredentialRevokeResult(
            storageKey: storageKey,
            credentialId: nil,
            remainingCredentials: 0
        )
    }

    func listCredentials(storageKey: String) async throws -> PasskeyBackupCredentialListResult {
        if let credentialListResult {
            return credentialListResult
        }
        return try PasskeyBackupCredentialListResult(storageKey: storageKey, credentials: [])
    }

    func revokeCredential(
        storageKey: String,
        credentialId: String
    ) async throws -> PasskeyBackupCredentialRevokeResult {
        revokedCredentialStorageKey = storageKey
        revokedCredentialId = credentialId
        if let revokeCredentialError {
            throw revokeCredentialError
        }
        if let revokeCredentialResult {
            return revokeCredentialResult
        }
        return try PasskeyBackupCredentialRevokeResult(
            storageKey: storageKey,
            credentialId: credentialId,
            remainingCredentials: 0
        )
    }
}

private final class LifecycleTestCloudStorage: PasskeyBackupCloudStorage {
    private var record: PasskeyBackupEncryptedRecord?
    private let saveError: Error?
    private let beforeDelete: () -> Void
    private(set) var deletedStorageKey: String?

    init(
        record: PasskeyBackupEncryptedRecord?,
        saveError: Error? = nil,
        beforeDelete: @escaping () -> Void = {}
    ) {
        self.record = record
        self.saveError = saveError
        self.beforeDelete = beforeDelete
    }

    func savePasskeyBackup(_ record: PasskeyBackupEncryptedRecord) async throws {
        if let saveError {
            throw saveError
        }
        self.record = record
    }

    func loadPasskeyBackup(storageKey: String) async throws -> PasskeyBackupEncryptedRecord? {
        guard record?.storageKey == storageKey else {
            return nil
        }
        return record
    }

    func deletePasskeyBackup(storageKey: String) async throws {
        beforeDelete()
        deletedStorageKey = storageKey
        record = nil
    }
}

private final class FixedTestBackupKeyProvider: RecoverablePasskeyBackupKeyProvider {
    func backupKey(for _: PasskeyBackupEnvelopeMetadata) async throws -> Data {
        Data((1 ... 32).map(UInt8.init))
    }
}

private actor CancellationSaveGate {
    private var saveStarted = false
    private var saveReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilSaveStarted() async {
        guard !saveStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func startSaveAndWaitForRelease() async {
        if !saveStarted {
            saveStarted = true
            let waiters = startWaiters
            startWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        guard !saveReleased else {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func releaseSave() {
        guard !saveReleased else {
            return
        }
        saveReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private actor CancellationCompletionGate {
    private var completionStarted = false
    private var completionReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilCompletionStarted() async {
        guard !completionStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func startCompletionAndWaitForRelease() async {
        if !completionStarted {
            completionStarted = true
            let waiters = startWaiters
            startWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        guard !completionReleased else {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func releaseCompletion() {
        guard !completionReleased else {
            return
        }
        completionReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private final class CancellationGateCloudStorage: PasskeyBackupCloudStorage {
    private let gate: CancellationSaveGate

    init(gate: CancellationSaveGate) {
        self.gate = gate
    }

    func savePasskeyBackup(_: PasskeyBackupEncryptedRecord) async throws {
        await gate.startSaveAndWaitForRelease()
        try Task.checkCancellation()
        throw PasskeyBackupError.unavailableCloudStorage
    }

    func loadPasskeyBackup(storageKey _: String) async throws -> PasskeyBackupEncryptedRecord? {
        nil
    }

    func deletePasskeyBackup(storageKey _: String) async throws {}
}

private actor BlockingRevokeGate {
    private var revokeStarted = false
    private var revokeReleased = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

    func waitUntilRevokeStarted() async {
        guard !revokeStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func startRevokeAndWaitForRelease() async {
        if !revokeStarted {
            revokeStarted = true
            let waiters = startWaiters
            startWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        guard !revokeReleased else {
            return
        }
        await withCheckedContinuation { continuation in
            releaseWaiters.append(continuation)
        }
    }

    func releaseRevoke() {
        guard !revokeReleased else {
            return
        }
        revokeReleased = true
        let waiters = releaseWaiters
        releaseWaiters.removeAll()
        waiters.forEach { $0.resume() }
    }
}

private struct CompensationRevocationSnapshot: Equatable {
    let storageKey: String?
    let credentialId: String?
    let observedCancellation: Bool?
}

private actor CompensationRevocationState {
    private var storageKey: String?
    private var credentialId: String?
    private var observedCancellation: Bool?

    func recordStart(wasCancelled: Bool) {
        observedCancellation = wasCancelled
    }

    func recordSuccess(storageKey: String, credentialId: String) {
        self.storageKey = storageKey
        self.credentialId = credentialId
    }

    func snapshot() -> CompensationRevocationSnapshot {
        CompensationRevocationSnapshot(
            storageKey: storageKey,
            credentialId: credentialId,
            observedCancellation: observedCancellation
        )
    }
}

private final class AdversarialCompensationChallengeService: PasskeyBackupChallengeService {
    private let revokeGate: BlockingRevokeGate?
    private let completionGate: CancellationCompletionGate?
    private let state = CompensationRevocationState()

    init(
        revokeGate: BlockingRevokeGate? = nil,
        completionGate: CancellationCompletionGate? = nil
    ) {
        self.revokeGate = revokeGate
        self.completionGate = completionGate
    }

    func registrationChallenge(
        walletId _: String,
        accountName _: String,
        displayName _: String
    ) async throws -> PasskeyBackupRegistrationChallenge {
        throw PasskeyBackupError.malformedChallengeServiceResponse
    }

    func completeRegistration(
        registrationId _: String,
        credentialResponseJSON _: String
    ) async throws -> PasskeyBackupChallengeResult {
        if let completionGate {
            await completionGate.startCompletionAndWaitForRelease()
            do {
                try Task.checkCancellation()
            } catch {
                throw PasskeyBackupError.registrationCompletionOutcomeUnknown
            }
        }
        return try PasskeyBackupChallengeResult(storageKey: "wallet-1234")
    }

    func assertionChallenge(storageKey _: String) async throws -> PasskeyBackupAssertionChallenge {
        throw PasskeyBackupError.malformedChallengeServiceResponse
    }

    func completeAssertion(
        assertionId _: String,
        credentialResponseJSON _: String
    ) async throws -> PasskeyBackupChallengeResult {
        throw PasskeyBackupError.malformedChallengeServiceResponse
    }

    func revokeCredential(
        storageKey: String,
        credentialId: String
    ) async throws -> PasskeyBackupCredentialRevokeResult {
        await state.recordStart(wasCancelled: Task.isCancelled)
        if let revokeGate {
            await revokeGate.startRevokeAndWaitForRelease()
        }
        try Task.checkCancellation()
        await state.recordSuccess(storageKey: storageKey, credentialId: credentialId)
        return try PasskeyBackupCredentialRevokeResult(
            storageKey: storageKey,
            credentialId: credentialId,
            remainingCredentials: 0
        )
    }

    func revokeAllCredentials(storageKey _: String) async throws -> PasskeyBackupCredentialRevokeResult {
        throw PasskeyBackupError.malformedChallengeServiceResponse
    }

    func revocationSnapshot() async -> CompensationRevocationSnapshot {
        await state.snapshot()
    }
}

private struct CompensationCompletionSnapshot {
    let isFinished: Bool
    let didPreserveOriginalError: Bool
}

private actor CompensationCompletionProbe {
    private var isFinished = false
    private var didPreserveOriginalError = false

    func record(didPreserveOriginalError: Bool) {
        isFinished = true
        self.didPreserveOriginalError = didPreserveOriginalError
    }

    func snapshot() -> CompensationCompletionSnapshot {
        CompensationCompletionSnapshot(
            isFinished: isFinished,
            didPreserveOriginalError: didPreserveOriginalError
        )
    }
}
