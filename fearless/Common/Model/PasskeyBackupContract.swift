import AuthenticationServices
import CloudKit
import CryptoKit
import Foundation

enum PasskeyBackupError: Error, Equatable {
    case unsupportedRelyingParty(String)
    case invalidChallengeLength(Int)
    case invalidUserIdLength(Int)
    case invalidUserName
    case invalidDisplayName
    case invalidStorageKey
    case invalidWalletId
    case invalidCreatedAtMillis
    case emptyEncryptedPayload
    case encryptedPayloadMetadataRequired
    case invalidEncryptedEnvelope
    case invalidBackupKeyLength(Int)
    case envelopeAuthenticationFailed
    case unavailableBackupKey
    case unsupportedSchemaVersion(Int)
    case unavailableCloudStorage
    case unavailableCloudKitAccount
    case invalidCloudKitRecordType(String)
    case missingCloudKitEncryptedPayload
    case invalidChallengeServiceURL(String)
    case invalidCeremonyId
    case challengeServiceHTTPStatus(Int)
    case emptyChallengeServiceResponse
    case malformedChallengeServiceResponse
    case invalidCredentialResponse
    case unexpectedCredentialType
    case ceremonyInProgress
    case ceremonyCancelled
    case invalidCompensationTimeout
    case invalidResponseSizeLimit
    case challengeServiceResponseTooLarge
    case registrationCompletionOutcomeUnknown
    case unavailableAuthorization
    case invalidAuthorizationToken
    case mismatchedChallengeStorageKey
    case missingCloudBackup
    case passkeyBackupDisabled
}

enum PasskeyBackupRegistrationCompensationFailureKind: Equatable {
    case revokeFailed
    case timedOut
}

struct PasskeyBackupRegistrationCompensationError: Error {
    let primaryError: Error
    let failureKind: PasskeyBackupRegistrationCompensationFailureKind
    let cleanupError: Error?
}

struct PasskeyBackupEnvelopeMetadata: Equatable {
    let storageKey: String
    let walletId: String
    let accountName: String
    let createdAtMillis: Int64
    let schemaVersion: Int

    init(
        storageKey: String,
        walletId: String,
        accountName: String,
        createdAtMillis: Int64,
        schemaVersion: Int = PasskeyBackupContract.schemaVersion
    ) throws {
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        self.walletId = try PasskeyBackupContract.validateWalletId(walletId)
        self.accountName = try PasskeyBackupContract.validateAccountName(accountName)
        self.createdAtMillis = try PasskeyBackupContract.validateCreatedAtMillis(createdAtMillis)
        guard schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.unsupportedSchemaVersion(schemaVersion)
        }
        self.schemaVersion = schemaVersion
    }

    fileprivate func canonicalAdditionalAuthenticatedData() -> Data {
        var data = Data("FPBKAAD1".utf8)
        data.appendBigEndian(UInt32(schemaVersion))
        data.appendBigEndian(UInt64(bitPattern: createdAtMillis))
        data.appendCanonicalUTF8(storageKey)
        data.appendCanonicalUTF8(walletId)
        data.appendCanonicalUTF8(accountName)
        return data
    }
}

protocol RecoverablePasskeyBackupKeyProvider {
    /// Returns exactly 32 recoverable bytes shared by the same wallet on every device.
    /// A device-local Keychain key is not a valid implementation of this contract.
    func backupKey(for metadata: PasskeyBackupEnvelopeMetadata) async throws -> Data
}

final class UnavailablePasskeyBackupKeyProvider: RecoverablePasskeyBackupKeyProvider {
    func backupKey(for _: PasskeyBackupEnvelopeMetadata) async throws -> Data {
        throw PasskeyBackupError.unavailableBackupKey
    }
}

protocol PasskeyBackupEnvelopeCryptography {
    /// Implementations must emit and consume PasskeyBackupEnvelopeV1Format envelopes.
    func encrypt(
        _ plaintext: Data,
        metadata: PasskeyBackupEnvelopeMetadata,
        key: Data
    ) throws -> Data

    func decrypt(
        _ envelope: Data,
        metadata: PasskeyBackupEnvelopeMetadata,
        key: Data
    ) throws -> Data

    func validateCanonicalEnvelope(_ envelope: Data) throws
}

enum PasskeyBackupEnvelopeV1Format {
    fileprivate static let magic = Data("FPBKAEAD".utf8)
    fileprivate static let version: UInt8 = 1
    fileprivate static let algorithmAES256GCM: UInt8 = 1
    fileprivate static let keyBytes = 32
    fileprivate static let nonceBytes = 12
    fileprivate static let tagBytes = 16
    fileprivate static let headerBytes = 16
    fileprivate static let maxEnvelopeBytes = 256 * 1024
    fileprivate static let maxPlaintextBytes = maxEnvelopeBytes - headerBytes - nonceBytes - tagBytes
    fileprivate static let minEnvelopeBytes = headerBytes + nonceBytes + tagBytes + 1

    static func validateCanonicalEnvelope(_ envelope: Data) throws {
        _ = try parse(envelope)
    }

    fileprivate static func parse(_ envelope: Data) throws -> ParsedEnvelope {
        guard (minEnvelopeBytes ... maxEnvelopeBytes).contains(envelope.count),
              envelope.prefix(magic.count) == magic,
              envelope[8] == version,
              envelope[9] == algorithmAES256GCM,
              envelope[10] == UInt8(nonceBytes),
              envelope[11] == UInt8(tagBytes) else {
            throw PasskeyBackupError.invalidEncryptedEnvelope
        }
        let ciphertextLength = Int(
            UInt32(envelope[12]) << 24 |
                UInt32(envelope[13]) << 16 |
                UInt32(envelope[14]) << 8 |
                UInt32(envelope[15])
        )
        guard (1 ... maxPlaintextBytes).contains(ciphertextLength),
              envelope.count == headerBytes + nonceBytes + ciphertextLength + tagBytes else {
            throw PasskeyBackupError.invalidEncryptedEnvelope
        }
        let nonceStart = headerBytes
        let ciphertextStart = nonceStart + nonceBytes
        let tagStart = ciphertextStart + ciphertextLength
        return ParsedEnvelope(
            nonce: envelope.subdata(in: nonceStart ..< ciphertextStart),
            ciphertext: envelope.subdata(in: ciphertextStart ..< tagStart),
            tag: envelope.subdata(in: tagStart ..< envelope.count)
        )
    }

    fileprivate struct ParsedEnvelope {
        let nonce: Data
        let ciphertext: Data
        let tag: Data
    }
}

struct AESGCMPasskeyBackupEnvelopeCryptography: PasskeyBackupEnvelopeCryptography {
    func encrypt(
        _ plaintext: Data,
        metadata: PasskeyBackupEnvelopeMetadata,
        key: Data
    ) throws -> Data {
        guard !plaintext.isEmpty,
              plaintext.count <= PasskeyBackupEnvelopeV1Format.maxPlaintextBytes else {
            throw PasskeyBackupError.invalidEncryptedEnvelope
        }
        let symmetricKey = try validatedKey(key)
        let sealed = try AES.GCM.seal(
            plaintext,
            using: symmetricKey,
            authenticating: metadata.canonicalAdditionalAuthenticatedData()
        )
        let nonce = Data(sealed.nonce)
        guard nonce.count == PasskeyBackupEnvelopeV1Format.nonceBytes,
              sealed.tag.count == PasskeyBackupEnvelopeV1Format.tagBytes,
              sealed.ciphertext.count == plaintext.count else {
            throw PasskeyBackupError.invalidEncryptedEnvelope
        }

        var envelope = PasskeyBackupEnvelopeV1Format.magic
        envelope.append(PasskeyBackupEnvelopeV1Format.version)
        envelope.append(PasskeyBackupEnvelopeV1Format.algorithmAES256GCM)
        envelope.append(UInt8(PasskeyBackupEnvelopeV1Format.nonceBytes))
        envelope.append(UInt8(PasskeyBackupEnvelopeV1Format.tagBytes))
        envelope.appendBigEndian(UInt32(sealed.ciphertext.count))
        envelope.append(nonce)
        envelope.append(sealed.ciphertext)
        envelope.append(sealed.tag)
        try validateCanonicalEnvelope(envelope)
        return envelope
    }

    func decrypt(
        _ envelope: Data,
        metadata: PasskeyBackupEnvelopeMetadata,
        key: Data
    ) throws -> Data {
        let parsed = try PasskeyBackupEnvelopeV1Format.parse(envelope)
        let symmetricKey = try validatedKey(key)
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(
                nonce: AES.GCM.Nonce(data: parsed.nonce),
                ciphertext: parsed.ciphertext,
                tag: parsed.tag
            )
            let plaintext = try AES.GCM.open(
                sealedBox,
                using: symmetricKey,
                authenticating: metadata.canonicalAdditionalAuthenticatedData()
            )
            guard !plaintext.isEmpty,
                  plaintext.count <= PasskeyBackupEnvelopeV1Format.maxPlaintextBytes else {
                throw PasskeyBackupError.envelopeAuthenticationFailed
            }
            return plaintext
        } catch let error as PasskeyBackupError {
            throw error
        } catch {
            throw PasskeyBackupError.envelopeAuthenticationFailed
        }
    }

    func validateCanonicalEnvelope(_ envelope: Data) throws {
        try PasskeyBackupEnvelopeV1Format.validateCanonicalEnvelope(envelope)
    }

    private func validatedKey(_ key: Data) throws -> SymmetricKey {
        guard key.count == PasskeyBackupEnvelopeV1Format.keyBytes else {
            throw PasskeyBackupError.invalidBackupKeyLength(key.count)
        }
        return SymmetricKey(data: key)
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt32) {
        append(UInt8((value >> 24) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8(value & 0xFF))
    }

    mutating func appendBigEndian(_ value: UInt64) {
        for shift in stride(from: 56, through: 0, by: -8) {
            append(UInt8((value >> UInt64(shift)) & 0xFF))
        }
    }

    mutating func appendCanonicalUTF8(_ value: String) {
        let encoded = Data(value.utf8)
        appendBigEndian(UInt32(encoded.count))
        append(encoded)
    }
}

enum PasskeyBackupContract {
    static let PASSKEY_RP_ID = "fearlesswallet.io"
    static let passkeyRelyingPartyId = PASSKEY_RP_ID
    static let schemaVersion = 1

    static func validateRelyingPartyId(_ relyingPartyId: String = PASSKEY_RP_ID) throws {
        guard relyingPartyId == PASSKEY_RP_ID else {
            throw PasskeyBackupError.unsupportedRelyingParty(relyingPartyId)
        }
    }

    static func validateChallenge(_ challenge: Data) throws {
        guard (16 ... 1024).contains(challenge.count) else {
            throw PasskeyBackupError.invalidChallengeLength(challenge.count)
        }
    }

    static func validateUserId(_ userId: Data) throws {
        guard userId.count == 32 else {
            throw PasskeyBackupError.invalidUserIdLength(userId.count)
        }
    }

    static func validateAccountName(_ accountName: String) throws -> String {
        let normalized = accountName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            throw PasskeyBackupError.invalidUserName
        }

        guard normalized.count <= 320 else {
            throw PasskeyBackupError.invalidUserName
        }

        guard normalized.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              normalized.rangeOfCharacter(from: .controlCharacters) == nil,
              normalized.filter({ $0 == "@" }).count == 1,
              !normalized.hasPrefix("@"),
              !normalized.hasSuffix("@") else {
            throw PasskeyBackupError.invalidUserName
        }

        return normalized
    }

    static func validateMatchingAccountName(
        expected: String,
        actual: String
    ) throws -> String {
        let normalizedExpected = try validateAccountName(expected)
        let normalizedActual = try validateAccountName(actual)

        guard normalizedActual.caseInsensitiveCompare(normalizedExpected) == .orderedSame else {
            throw PasskeyBackupError.invalidUserName
        }

        return normalizedExpected
    }

    static func validateStorageKey(_ storageKey: String) throws -> String {
        let normalized = storageKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Za-z0-9._:-]{8,128}$"#
        let range = NSRange(normalized.startIndex ..< normalized.endIndex, in: normalized)
        let regex = try NSRegularExpression(pattern: pattern)

        guard regex.firstMatch(in: normalized, range: range) != nil else {
            throw PasskeyBackupError.invalidStorageKey
        }

        return normalized
    }

    static func validateWalletId(_ walletId: String) throws -> String {
        let normalized = walletId.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Za-z0-9._:-]{8,128}$"#
        let range = NSRange(normalized.startIndex ..< normalized.endIndex, in: normalized)
        let regex = try NSRegularExpression(pattern: pattern)

        guard regex.firstMatch(in: normalized, range: range) != nil else {
            throw PasskeyBackupError.invalidWalletId
        }

        return normalized
    }

    static func validateCreatedAtMillis(_ createdAtMillis: Int64) throws -> Int64 {
        guard createdAtMillis > 0,
              createdAtMillis <= 4_102_444_800_000 else {
            throw PasskeyBackupError.invalidCreatedAtMillis
        }

        return createdAtMillis
    }

    static func validateCeremonyId(_ ceremonyId: String) throws -> String {
        let normalized = ceremonyId.trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^[A-Za-z0-9._:-]{8,128}$"#
        let range = NSRange(normalized.startIndex ..< normalized.endIndex, in: normalized)
        let regex = try NSRegularExpression(pattern: pattern)

        guard regex.firstMatch(in: normalized, range: range) != nil else {
            throw PasskeyBackupError.invalidCeremonyId
        }

        return normalized
    }

    static func validateCredentialId(_ credentialId: String) throws -> String {
        guard (1 ... 512).contains(credentialId.count),
              let decoded = try? decodeBase64URL(credentialId),
              !decoded.isEmpty else {
            throw PasskeyBackupError.invalidCredentialResponse
        }
        return credentialId
    }

    static func decodeBase64URL(_ value: String) throws -> Data {
        guard !value.isEmpty,
              value.range(of: #"\A[A-Za-z0-9_-]+\z"#, options: .regularExpression) != nil,
              value.count % 4 != 1 else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        switch base64.count % 4 {
        case 0:
            break
        case 2:
            base64.append("==")
        case 3:
            base64.append("=")
        default:
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        guard let data = Data(base64Encoded: base64),
              data.base64EncodedString()
              .replacingOccurrences(of: "+", with: "-")
              .replacingOccurrences(of: "/", with: "_")
              .replacingOccurrences(of: "=", with: "") == value else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return data
    }
}

enum PasskeyCredentialResponseSerializer {
    private static let maxCredentialIdEncodedLength = 512
    private static let maxClientDataEncodedLength = 8192
    private static let maxCredentialBlobEncodedLength = 32768

    static func registrationJSON(
        credentialID: Data,
        clientDataJSON: Data,
        attestationObject: Data,
        authenticatorData: Data? = nil
    ) throws -> String {
        var response: [String: Any] = [
            "clientDataJSON": try encodeRequired(
                clientDataJSON,
                maxEncodedLength: maxClientDataEncodedLength
            ),
            "attestationObject": try encodeRequired(attestationObject)
        ]

        if let authenticatorData {
            response["authenticatorData"] = try encodeRequired(authenticatorData)
        }

        return try credentialJSON(
            credentialID: credentialID,
            response: response
        )
    }

    static func assertionJSON(
        credentialID: Data,
        clientDataJSON: Data,
        authenticatorData: Data,
        signature: Data,
        userHandle: Data
    ) throws -> String {
        do {
            try PasskeyBackupContract.validateUserId(userHandle)
        } catch {
            throw PasskeyBackupError.invalidCredentialResponse
        }

        let response: [String: Any] = [
            "clientDataJSON": try encodeRequired(
                clientDataJSON,
                maxEncodedLength: maxClientDataEncodedLength
            ),
            "authenticatorData": try encodeRequired(authenticatorData),
            "signature": try encodeRequired(signature),
            "userHandle": try encodeRequired(userHandle)
        ]

        return try credentialJSON(
            credentialID: credentialID,
            response: response
        )
    }

    @available(iOS 15.0, macOS 12.0, *)
    static func registrationJSON(
        for credential: ASAuthorizationPlatformPublicKeyCredentialRegistration
    ) throws -> String {
        guard let attestationObject = credential.rawAttestationObject else {
            throw PasskeyBackupError.invalidCredentialResponse
        }

        return try registrationJSON(
            credentialID: credential.credentialID,
            clientDataJSON: credential.rawClientDataJSON,
            attestationObject: attestationObject
        )
    }

    @available(iOS 15.0, macOS 12.0, *)
    static func assertionJSON(
        for credential: ASAuthorizationPlatformPublicKeyCredentialAssertion
    ) throws -> String {
        try assertionJSON(
            credentialID: credential.credentialID,
            clientDataJSON: credential.rawClientDataJSON,
            authenticatorData: credential.rawAuthenticatorData,
            signature: credential.signature,
            userHandle: credential.userID
        )
    }

    private static func credentialJSON(
        credentialID: Data,
        response: [String: Any]
    ) throws -> String {
        let encodedCredentialID = try encodeRequired(
            credentialID,
            maxEncodedLength: maxCredentialIdEncodedLength
        )
        let credential: [String: Any] = [
            "id": encodedCredentialID,
            "rawId": encodedCredentialID,
            "response": response,
            "type": "public-key",
            "clientExtensionResults": [String: Any](),
            "authenticatorAttachment": "platform"
        ]

        guard JSONSerialization.isValidJSONObject(credential),
              let json = try? JSONSerialization.data(
                  withJSONObject: credential,
                  options: [.sortedKeys]
              ),
              let serialized = String(data: json, encoding: .utf8) else {
            throw PasskeyBackupError.invalidCredentialResponse
        }

        return serialized
    }

    private static func encodeRequired(
        _ data: Data,
        maxEncodedLength: Int = maxCredentialBlobEncodedLength
    ) throws -> String {
        guard !data.isEmpty else {
            throw PasskeyBackupError.invalidCredentialResponse
        }

        let encoded = data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        guard encoded.count <= maxEncodedLength else {
            throw PasskeyBackupError.invalidCredentialResponse
        }

        return encoded
    }
}

enum PasskeyBackupReleaseConfig {
    static let challengeServiceBaseURL = URL(string: "https://backup.fearlesswallet.io")!
    static let isPasskeyBackupEnabled = false
    static let passkeyBackupEnabled = isPasskeyBackupEnabled

    static func validateEnabled(_ isEnabled: Bool = isPasskeyBackupEnabled) throws {
        guard isEnabled else {
            throw PasskeyBackupError.passkeyBackupDisabled
        }
    }
}

struct PasskeyBackupRegistrationChallenge: Equatable {
    let registrationId: String
    let challenge: Data
    let userId: Data
    let userName: String
    let displayName: String
    let storageKey: String
    let schemaVersion: Int

    init(
        registrationId: String,
        challenge: Data,
        userId: Data,
        userName: String,
        displayName: String,
        storageKey: String,
        schemaVersion: Int = PasskeyBackupContract.schemaVersion
    ) throws {
        self.registrationId = try PasskeyBackupContract.validateCeremonyId(registrationId)
        try PasskeyBackupContract.validateChallenge(challenge)
        try PasskeyBackupContract.validateUserId(userId)

        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDisplayName.isEmpty, normalizedDisplayName.count <= 128 else {
            throw PasskeyBackupError.invalidDisplayName
        }

        guard schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.unsupportedSchemaVersion(schemaVersion)
        }

        self.challenge = challenge
        self.userId = userId
        self.userName = try PasskeyBackupContract.validateAccountName(userName)
        self.displayName = normalizedDisplayName
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        self.schemaVersion = schemaVersion
    }
}

struct PasskeyBackupAssertionChallenge: Equatable {
    let assertionId: String
    let challenge: Data
    let storageKey: String
    let schemaVersion: Int

    init(
        assertionId: String,
        challenge: Data,
        storageKey: String,
        schemaVersion: Int = PasskeyBackupContract.schemaVersion
    ) throws {
        self.assertionId = try PasskeyBackupContract.validateCeremonyId(assertionId)
        try PasskeyBackupContract.validateChallenge(challenge)

        guard schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.unsupportedSchemaVersion(schemaVersion)
        }

        self.challenge = challenge
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        self.schemaVersion = schemaVersion
    }
}

struct PasskeyBackupChallengeResult: Equatable {
    let storageKey: String
    let schemaVersion: Int

    init(
        storageKey: String,
        schemaVersion: Int = PasskeyBackupContract.schemaVersion
    ) throws {
        guard schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.unsupportedSchemaVersion(schemaVersion)
        }

        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        self.schemaVersion = schemaVersion
    }
}

struct PasskeyBackupCredentialSummary: Equatable {
    let id: String
    let aaguid: String
    let registrationPlatform: String
    let deviceType: String
    let backedUp: Bool
    let transports: [String]?

    init(
        id: String,
        aaguid: String,
        registrationPlatform: String,
        deviceType: String,
        backedUp: Bool,
        transports: [String]? = nil
    ) throws {
        self.id = try PasskeyBackupContract.validateCredentialId(id)
        guard aaguid.range(
            of: #"\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z"#,
            options: .regularExpression
        ) != nil,
            ["android", "ios"].contains(registrationPlatform),
            ["singleDevice", "multiDevice"].contains(deviceType),
            deviceType != "singleDevice" || !backedUp else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        if let transports {
            let supported = Set(["ble", "cable", "hybrid", "internal", "nfc", "smart-card", "usb"])
            guard transports.count <= supported.count,
                  Set(transports).count == transports.count,
                  transports.allSatisfy(supported.contains) else {
                throw PasskeyBackupError.malformedChallengeServiceResponse
            }
        }
        self.aaguid = aaguid
        self.registrationPlatform = registrationPlatform
        self.deviceType = deviceType
        self.backedUp = backedUp
        self.transports = transports
    }
}

struct PasskeyBackupCredentialListResult: Equatable {
    let storageKey: String
    let credentials: [PasskeyBackupCredentialSummary]
    let schemaVersion: Int

    init(
        storageKey: String,
        credentials: [PasskeyBackupCredentialSummary],
        schemaVersion: Int = PasskeyBackupContract.schemaVersion
    ) throws {
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        guard credentials.count <= 32,
              Set(credentials.map(\.id)).count == credentials.count,
              schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        self.credentials = credentials
        self.schemaVersion = schemaVersion
    }
}

struct PasskeyBackupCredentialRevokeResult: Equatable {
    let storageKey: String
    let credentialId: String?
    let remainingCredentials: Int
    let schemaVersion: Int

    init(
        storageKey: String,
        credentialId: String?,
        remainingCredentials: Int,
        schemaVersion: Int = PasskeyBackupContract.schemaVersion
    ) throws {
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        self.credentialId = try credentialId.map(PasskeyBackupContract.validateCredentialId)
        guard (0 ... 32).contains(remainingCredentials),
              schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        self.remainingCredentials = remainingCredentials
        self.schemaVersion = schemaVersion
    }
}

protocol PasskeyBackupChallengeService {
    func registrationChallenge(
        walletId: String,
        accountName: String,
        displayName: String
    ) async throws -> PasskeyBackupRegistrationChallenge

    func completeRegistration(
        registrationId: String,
        credentialResponseJSON: String
    ) async throws -> PasskeyBackupChallengeResult

    func assertionChallenge(storageKey: String) async throws -> PasskeyBackupAssertionChallenge

    func completeAssertion(
        assertionId: String,
        credentialResponseJSON: String
    ) async throws -> PasskeyBackupChallengeResult

    func listCredentials(storageKey: String) async throws -> PasskeyBackupCredentialListResult

    func revokeCredential(
        storageKey: String,
        credentialId: String
    ) async throws -> PasskeyBackupCredentialRevokeResult

    func revokeAllCredentials(storageKey: String) async throws -> PasskeyBackupCredentialRevokeResult
}

extension PasskeyBackupChallengeService {
    func listCredentials(storageKey _: String) async throws -> PasskeyBackupCredentialListResult {
        throw PasskeyBackupError.unavailableAuthorization
    }

    func revokeCredential(
        storageKey _: String,
        credentialId _: String
    ) async throws -> PasskeyBackupCredentialRevokeResult {
        throw PasskeyBackupError.unavailableAuthorization
    }

    func revokeAllCredentials(storageKey _: String) async throws -> PasskeyBackupCredentialRevokeResult {
        throw PasskeyBackupError.unavailableAuthorization
    }
}

struct PasskeyBackupAuthorizationRequest: Equatable {
    static let registrationChallengePath = "/api/passkey-backup/v1/registration/challenge"
    static let registrationCompletePath = "/api/passkey-backup/v1/registration/complete"
    static let assertionChallengePath = "/api/passkey-backup/v1/assertion/challenge"
    static let assertionCompletePath = "/api/passkey-backup/v1/assertion/complete"
    static let credentialsListPath = "/api/passkey-backup/v1/credentials/list"
    static let credentialsRevokePath = "/api/passkey-backup/v1/credentials/revoke"
    static let credentialsRevokeAllPath = "/api/passkey-backup/v1/credentials/revoke-all"

    private static let allowedPaths: Set<String> = [
        registrationChallengePath,
        registrationCompletePath,
        assertionChallengePath,
        assertionCompletePath,
        credentialsListPath,
        credentialsRevokePath,
        credentialsRevokeAllPath
    ]

    let method: String
    let path: String
    let bodySha256: String

    init(method: String, path: String, bodySha256: String) throws {
        guard method == "POST",
              Self.allowedPaths.contains(path),
              Self.isCanonicalSHA256(bodySha256) else {
            throw PasskeyBackupError.invalidAuthorizationToken
        }

        self.method = method
        self.path = path
        self.bodySha256 = bodySha256
    }

    private static func isCanonicalSHA256(_ value: String) -> Bool {
        guard let decoded = try? PasskeyBackupContract.decodeBase64URL(value),
              decoded.count == 32 else {
            return false
        }

        return true
    }
}

protocol PasskeyBackupAuthorizationProvider {
    /// Returns a one-time opaque grant for the exact request body. The issuer's
    /// subject must represent stable Fearless wallet ownership, not a raw
    /// Google, Apple, or device account identifier.
    func authorizationToken(for request: PasskeyBackupAuthorizationRequest) async throws -> String
}

final class UnavailableBackupAuthorizationProvider: PasskeyBackupAuthorizationProvider {
    func authorizationToken(for _: PasskeyBackupAuthorizationRequest) async throws -> String {
        throw PasskeyBackupError.unavailableAuthorization
    }
}

struct PasskeyBackupHTTPRequest: Equatable {
    let method: String
    let url: URL
    let headers: [String: String]
    let body: Data?

    init(
        method: String,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.body = body
    }
}

struct PasskeyBackupHTTPResponse: Equatable {
    let statusCode: Int
    let body: Data

    init(statusCode: Int, body: Data = Data()) {
        self.statusCode = statusCode
        self.body = body
    }
}

protocol PasskeyBackupHTTPTransport {
    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse
}

enum PasskeyBackupHTTPTransportPolicy {
    static let requestTimeout: TimeInterval = 15
    static let resourceTimeout: TimeInterval = 30
    static let maximumResponseBytes = 256 * 1024
    static let followsRedirects = false
}

@available(iOS 15.0, macOS 12.0, *)
final class PasskeyBackupBoundedSessionDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private final class RequestCancellationState: @unchecked Sendable {
        let lock = NSLock()
        var isCancelled = false
    }

    private struct RequestState {
        var data = Data()
        var response: URLResponse?
        let continuation: CheckedContinuation<(Data, URLResponse), Error>
    }

    private let maximumResponseBytes: Int
    private let lock = NSLock()
    private var states: [Int: RequestState] = [:]

    init(maximumResponseBytes: Int) {
        self.maximumResponseBytes = maximumResponseBytes
    }

    var inFlightRequestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return states.count
    }

    static func redirectedRequest(_ request: URLRequest) -> URLRequest? {
        PasskeyBackupHTTPTransportPolicy.followsRedirects ? request : nil
    }

    func data(for request: URLRequest, session: URLSession) async throws -> (Data, URLResponse) {
        let task = session.dataTask(with: request)
        let cancellationState = RequestCancellationState()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                cancellationState.lock.lock()
                let wasCancelled = cancellationState.isCancelled
                if !wasCancelled {
                    lock.lock()
                    states[task.taskIdentifier] = RequestState(continuation: continuation)
                    lock.unlock()
                }
                cancellationState.lock.unlock()

                if wasCancelled {
                    task.cancel()
                    continuation.resume(throwing: CancellationError())
                } else {
                    task.resume()
                }
            }
        } onCancel: {
            self.cancel(task: task, cancellationState: cancellationState)
        }
    }

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(Self.redirectedRequest(request))
    }

    func urlSession(
        _: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        if response.expectedContentLength > Int64(maximumResponseBytes) {
            resolveOversized(task: dataTask)
            completionHandler(.cancel)
            return
        }

        lock.lock()
        if var state = states[dataTask.taskIdentifier] {
            state.response = response
            states[dataTask.taskIdentifier] = state
        }
        lock.unlock()
        completionHandler(.allow)
    }

    func urlSession(_: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        var oversized = false
        lock.lock()
        if var state = states[dataTask.taskIdentifier] {
            let (nextCount, overflowed) = state.data.count.addingReportingOverflow(data.count)
            if overflowed || nextCount > maximumResponseBytes {
                oversized = true
            } else {
                state.data.append(data)
                states[dataTask.taskIdentifier] = state
            }
        }
        lock.unlock()

        if oversized {
            resolveOversized(task: dataTask)
            dataTask.cancel()
        }
    }

    func urlSession(
        _: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        lock.lock()
        let state = states.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        guard let state else {
            return
        }

        if let error {
            state.continuation.resume(throwing: error)
        } else if let response = state.response {
            state.continuation.resume(returning: (state.data, response))
        } else {
            state.continuation.resume(throwing: PasskeyBackupError.malformedChallengeServiceResponse)
        }
    }

    private func resolveOversized(task: URLSessionTask) {
        lock.lock()
        let state = states.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        state?.continuation.resume(throwing: PasskeyBackupError.challengeServiceResponseTooLarge)
    }

    private func cancel(
        task: URLSessionTask,
        cancellationState: RequestCancellationState
    ) {
        cancellationState.lock.lock()
        cancellationState.isCancelled = true
        lock.lock()
        let state = states.removeValue(forKey: task.taskIdentifier)
        lock.unlock()
        cancellationState.lock.unlock()

        task.cancel()
        state?.continuation.resume(throwing: CancellationError())
    }
}

@available(iOS 15.0, macOS 12.0, *)
final class URLSessionPasskeyBackupHTTPTransport: PasskeyBackupHTTPTransport {
    private let session: URLSession
    private let delegate: PasskeyBackupBoundedSessionDelegate

    init(
        configuration: URLSessionConfiguration? = nil,
        maximumResponseBytes: Int = PasskeyBackupHTTPTransportPolicy.maximumResponseBytes
    ) throws {
        guard (1 ... PasskeyBackupHTTPTransportPolicy.maximumResponseBytes)
            .contains(maximumResponseBytes) else {
            throw PasskeyBackupError.invalidResponseSizeLimit
        }
        let configuration = (configuration ?? .ephemeral).copy() as! URLSessionConfiguration
        configuration.timeoutIntervalForRequest = PasskeyBackupHTTPTransportPolicy.requestTimeout
        configuration.timeoutIntervalForResource = PasskeyBackupHTTPTransportPolicy.resourceTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        delegate = PasskeyBackupBoundedSessionDelegate(maximumResponseBytes: maximumResponseBytes)
        session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    deinit {
        session.invalidateAndCancel()
    }

    var inFlightRequestCount: Int { delegate.inFlightRequestCount }

    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body

        let (data, response) = try await delegate.data(for: urlRequest, session: session)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return PasskeyBackupHTTPResponse(statusCode: httpResponse.statusCode, body: data)
    }
}

final class HTTPPasskeyBackupChallengeService: PasskeyBackupChallengeService {
    private static let expectedResponseKeysByPath: [String: Set<String>] = [
        PasskeyBackupAuthorizationRequest.registrationChallengePath: [
            "registrationId", "challenge", "userId", "userName", "displayName",
            "storageKey", "rpId", "schemaVersion"
        ],
        PasskeyBackupAuthorizationRequest.registrationCompletePath: [
            "storageKey", "rpId", "schemaVersion"
        ],
        PasskeyBackupAuthorizationRequest.assertionChallengePath: [
            "assertionId", "challenge", "storageKey", "rpId", "schemaVersion"
        ],
        PasskeyBackupAuthorizationRequest.assertionCompletePath: [
            "storageKey", "rpId", "schemaVersion"
        ],
        PasskeyBackupAuthorizationRequest.credentialsListPath: [
            "storageKey", "credentials", "rpId", "schemaVersion"
        ],
        PasskeyBackupAuthorizationRequest.credentialsRevokePath: [
            "storageKey", "credentialId", "remainingCredentials", "rpId", "schemaVersion"
        ],
        PasskeyBackupAuthorizationRequest.credentialsRevokeAllPath: [
            "storageKey", "remainingCredentials", "rpId", "schemaVersion"
        ]
    ]

    private let baseURL: URL
    private let transport: PasskeyBackupHTTPTransport
    private let authorizationProvider: PasskeyBackupAuthorizationProvider

    convenience init(
        baseURL: String,
        transport: PasskeyBackupHTTPTransport,
        authorizationProvider: PasskeyBackupAuthorizationProvider =
            UnavailableBackupAuthorizationProvider()
    ) throws {
        let normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized == baseURL, let url = URL(string: normalized) else {
            throw PasskeyBackupError.invalidChallengeServiceURL(baseURL)
        }

        try self.init(
            baseURL: url,
            transport: transport,
            authorizationProvider: authorizationProvider
        )
    }

    init(
        baseURL: URL,
        transport: PasskeyBackupHTTPTransport,
        authorizationProvider: PasskeyBackupAuthorizationProvider =
            UnavailableBackupAuthorizationProvider()
    ) throws {
        self.baseURL = try Self.normalizedBaseURL(baseURL)
        self.transport = transport
        self.authorizationProvider = authorizationProvider
    }

    @available(iOS 15.0, macOS 12.0, *)
    convenience init(
        baseURL: String,
        authorizationProvider: PasskeyBackupAuthorizationProvider =
            UnavailableBackupAuthorizationProvider()
    ) throws {
        try self.init(
            baseURL: baseURL,
            transport: try URLSessionPasskeyBackupHTTPTransport(),
            authorizationProvider: authorizationProvider
        )
    }

    private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
        let requestBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let authorizationRequest = try PasskeyBackupAuthorizationRequest(
            method: "POST",
            path: path,
            bodySha256: Self.sha256Base64URL(requestBody)
        )
        let authorizationToken = try Self.validAuthorizationToken(
            await authorizationProvider.authorizationToken(for: authorizationRequest)
        )
        let response: PasskeyBackupHTTPResponse
        do {
            response = try await transport.execute(
                PasskeyBackupHTTPRequest(
                    method: "POST",
                    url: endpoint(path: path),
                    headers: [
                        "Content-Type": "application/json; charset=utf-8",
                        "Authorization": "Bearer \(authorizationToken)"
                    ],
                    body: requestBody
                )
            )
        } catch let error as CancellationError {
            if path == PasskeyBackupAuthorizationRequest.registrationCompletePath {
                throw PasskeyBackupError.registrationCompletionOutcomeUnknown
            }
            throw error
        } catch {
            if path == PasskeyBackupAuthorizationRequest.registrationCompletePath {
                throw PasskeyBackupError.registrationCompletionOutcomeUnknown
            }
            throw error
        }

        // Keep the service safe when a test, alternate client, or future
        // composition injects a transport that does not enforce URLSession's
        // streaming response cap.
        guard response.body.count <= PasskeyBackupHTTPTransportPolicy.maximumResponseBytes else {
            throw PasskeyBackupError.challengeServiceResponseTooLarge
        }

        guard response.statusCode == 200 else {
            if path == PasskeyBackupAuthorizationRequest.registrationCompletePath,
               Self.isAmbiguousRegistrationCompletionStatus(response.statusCode) {
                throw PasskeyBackupError.registrationCompletionOutcomeUnknown
            }
            throw PasskeyBackupError.challengeServiceHTTPStatus(response.statusCode)
        }

        guard !response.body.isEmpty else {
            if path == PasskeyBackupAuthorizationRequest.registrationCompletePath {
                throw PasskeyBackupError.registrationCompletionOutcomeUnknown
            }
            throw PasskeyBackupError.emptyChallengeServiceResponse
        }

        do {
            guard let root = try JSONSerialization.jsonObject(with: response.body) as? [String: Any],
                  let expectedKeys = Self.expectedResponseKeysByPath[path],
                  Set(root.keys) == expectedKeys else {
                throw PasskeyBackupError.malformedChallengeServiceResponse
            }

            return root
        } catch let error as PasskeyBackupError {
            if path == PasskeyBackupAuthorizationRequest.registrationCompletePath,
               error == .malformedChallengeServiceResponse {
                throw PasskeyBackupError.registrationCompletionOutcomeUnknown
            }
            throw error
        } catch {
            if path == PasskeyBackupAuthorizationRequest.registrationCompletePath {
                throw PasskeyBackupError.registrationCompletionOutcomeUnknown
            }
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
    }

    private func endpoint(path: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        var basePath = components.percentEncodedPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let endpointPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if !basePath.isEmpty {
            basePath += "/"
        }

        components.percentEncodedPath = "/" + basePath + endpointPath
        return components.url!
    }

    private static func isAmbiguousRegistrationCompletionStatus(_ statusCode: Int) -> Bool {
        (500 ... 599).contains(statusCode) || [408, 425, 429].contains(statusCode)
    }

    private func challengeResult(_ response: [String: Any]) throws -> PasskeyBackupChallengeResult {
        try requireRelyingPartyId(response)
        return try PasskeyBackupChallengeResult(
            storageKey: requiredString(response, name: "storageKey"),
            schemaVersion: requiredInt(response, name: "schemaVersion")
        )
    }

    private func requireRelyingPartyId(_ response: [String: Any]) throws {
        try PasskeyBackupContract.validateRelyingPartyId(requiredString(response, name: "rpId"))
    }

    private func credentialJSONObject(_ credentialResponseJSON: String) throws -> [String: Any] {
        let normalized = credentialResponseJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, let data = normalized.data(using: .utf8) else {
            throw PasskeyBackupError.invalidCredentialResponse
        }

        do {
            guard let credential = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  !credential.isEmpty else {
                throw PasskeyBackupError.invalidCredentialResponse
            }

            return credential
        } catch let error as PasskeyBackupError {
            throw error
        } catch {
            throw PasskeyBackupError.invalidCredentialResponse
        }
    }

    private func requiredString(_ response: [String: Any], name: String) throws -> String {
        guard let value = response[name] as? String,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return value
    }

    private func requiredInt(_ response: [String: Any], name: String) throws -> Int {
        guard let value = response[name] as? NSNumber,
              String(cString: value.objCType) != "c",
              value.stringValue.range(
                  of: #"\A(0|[1-9][0-9]*)\z"#,
                  options: .regularExpression
              ) != nil,
              let parsed = Int(value.stringValue) else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return parsed
    }

    private func requiredBool(_ response: [String: Any], name: String) throws -> Bool {
        guard let value = response[name] as? NSNumber,
              String(cString: value.objCType) == "c" else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        return value.boolValue
    }

    private static func requiredLocalString(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 128 else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return normalized
    }

    private static func sha256Base64URL(_ data: Data) -> String {
        Data(SHA256.hash(data: data))
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func validAuthorizationToken(_ token: String) throws -> String {
        guard (1 ... 4096).contains(token.utf8.count),
              token.range(
                  of: #"\A[A-Za-z0-9._~+/\-]+={0,}\z"#,
                  options: .regularExpression
              ) != nil else {
            throw PasskeyBackupError.invalidAuthorizationToken
        }
        return token
    }

    private static func normalizedBaseURL(_ url: URL) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https",
              !(components.host ?? "").isEmpty,
              components.host == components.host?.lowercased(),
              components.user == nil,
              components.password == nil,
              components.port == nil,
              components.query == nil,
              components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/" else {
            throw PasskeyBackupError.invalidChallengeServiceURL(url.absoluteString)
        }

        let host = components.host!
        let canonicalURL = "https://\(host)"
        guard url.absoluteString == canonicalURL || url.absoluteString == canonicalURL + "/" else {
            throw PasskeyBackupError.invalidChallengeServiceURL(url.absoluteString)
        }
        components.percentEncodedPath = ""

        guard let normalized = components.url else {
            throw PasskeyBackupError.invalidChallengeServiceURL(url.absoluteString)
        }

        return normalized
    }
}

extension HTTPPasskeyBackupChallengeService {
    func registrationChallenge(
        walletId: String,
        accountName: String,
        displayName: String
    ) async throws -> PasskeyBackupRegistrationChallenge {
        let normalizedWalletId = try PasskeyBackupContract.validateWalletId(walletId)
        let normalizedAccountName = try PasskeyBackupContract.validateAccountName(accountName)
        let normalizedDisplayName = try Self.requiredLocalString(displayName)

        let response = try await post(
            path: PasskeyBackupAuthorizationRequest.registrationChallengePath,
            body: [
                "walletId": normalizedWalletId,
                "accountName": normalizedAccountName,
                "displayName": normalizedDisplayName,
                "rpId": PasskeyBackupContract.PASSKEY_RP_ID,
                "schemaVersion": PasskeyBackupContract.schemaVersion
            ]
        )

        try requireRelyingPartyId(response)
        let schemaVersion = try requiredInt(response, name: "schemaVersion")

        return try PasskeyBackupRegistrationChallenge(
            registrationId: requiredString(response, name: "registrationId"),
            challenge: try PasskeyBackupContract.decodeBase64URL(
                requiredString(response, name: "challenge")
            ),
            userId: try PasskeyBackupContract.decodeBase64URL(
                requiredString(response, name: "userId")
            ),
            userName: requiredString(response, name: "userName"),
            displayName: requiredString(response, name: "displayName"),
            storageKey: requiredString(response, name: "storageKey"),
            schemaVersion: schemaVersion
        )
    }

    func completeRegistration(
        registrationId: String,
        credentialResponseJSON: String
    ) async throws -> PasskeyBackupChallengeResult {
        let response = try await post(
            path: PasskeyBackupAuthorizationRequest.registrationCompletePath,
            body: [
                "registrationId": try PasskeyBackupContract.validateCeremonyId(registrationId),
                "rpId": PasskeyBackupContract.PASSKEY_RP_ID,
                "credential": try credentialJSONObject(credentialResponseJSON)
            ]
        )

        do {
            return try challengeResult(response)
        } catch {
            throw PasskeyBackupError.registrationCompletionOutcomeUnknown
        }
    }

    func assertionChallenge(storageKey: String) async throws -> PasskeyBackupAssertionChallenge {
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let response = try await post(
            path: PasskeyBackupAuthorizationRequest.assertionChallengePath,
            body: [
                "storageKey": normalizedStorageKey,
                "rpId": PasskeyBackupContract.PASSKEY_RP_ID,
                "schemaVersion": PasskeyBackupContract.schemaVersion
            ]
        )

        try requireRelyingPartyId(response)
        let responseStorageKey = try PasskeyBackupContract.validateStorageKey(
            requiredString(response, name: "storageKey")
        )

        guard responseStorageKey == normalizedStorageKey else {
            throw PasskeyBackupError.mismatchedChallengeStorageKey
        }

        return try PasskeyBackupAssertionChallenge(
            assertionId: requiredString(response, name: "assertionId"),
            challenge: try PasskeyBackupContract.decodeBase64URL(
                requiredString(response, name: "challenge")
            ),
            storageKey: responseStorageKey,
            schemaVersion: requiredInt(response, name: "schemaVersion")
        )
    }

    func completeAssertion(
        assertionId: String,
        credentialResponseJSON: String
    ) async throws -> PasskeyBackupChallengeResult {
        let response = try await post(
            path: PasskeyBackupAuthorizationRequest.assertionCompletePath,
            body: [
                "assertionId": try PasskeyBackupContract.validateCeremonyId(assertionId),
                "rpId": PasskeyBackupContract.PASSKEY_RP_ID,
                "credential": try credentialJSONObject(credentialResponseJSON)
            ]
        )

        return try challengeResult(response)
    }
}

extension HTTPPasskeyBackupChallengeService {
    func listCredentials(storageKey: String) async throws -> PasskeyBackupCredentialListResult {
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let response = try await post(
            path: PasskeyBackupAuthorizationRequest.credentialsListPath,
            body: lifecycleBody(storageKey: normalizedStorageKey)
        )
        try requireRelyingPartyId(response)
        try requireResponseStorageKey(response, expected: normalizedStorageKey)
        guard let rawCredentials = response["credentials"] as? [Any], rawCredentials.count <= 32 else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        let credentials = try rawCredentials.map { value -> PasskeyBackupCredentialSummary in
            guard let credential = value as? [String: Any] else {
                throw PasskeyBackupError.malformedChallengeServiceResponse
            }
            let requiredKeys: Set<String> = [
                "id", "aaguid", "registrationPlatform", "deviceType", "backedUp"
            ]
            guard Set(credential.keys) == requiredKeys ||
                Set(credential.keys) == requiredKeys.union(["transports"]) else {
                throw PasskeyBackupError.malformedChallengeServiceResponse
            }
            let transports: [String]?
            if let rawTransports = credential["transports"] {
                guard let values = rawTransports as? [String] else {
                    throw PasskeyBackupError.malformedChallengeServiceResponse
                }
                transports = values
            } else {
                transports = nil
            }
            return try PasskeyBackupCredentialSummary(
                id: requiredString(credential, name: "id"),
                aaguid: requiredString(credential, name: "aaguid"),
                registrationPlatform: requiredString(credential, name: "registrationPlatform"),
                deviceType: requiredString(credential, name: "deviceType"),
                backedUp: try requiredBool(credential, name: "backedUp"),
                transports: transports
            )
        }
        return try PasskeyBackupCredentialListResult(
            storageKey: normalizedStorageKey,
            credentials: credentials,
            schemaVersion: requiredInt(response, name: "schemaVersion")
        )
    }

    func revokeCredential(
        storageKey: String,
        credentialId: String
    ) async throws -> PasskeyBackupCredentialRevokeResult {
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let normalizedCredentialId = try PasskeyBackupContract.validateCredentialId(credentialId)
        var body = lifecycleBody(storageKey: normalizedStorageKey)
        body["credentialId"] = normalizedCredentialId
        let response = try await post(
            path: PasskeyBackupAuthorizationRequest.credentialsRevokePath,
            body: body
        )
        try requireRelyingPartyId(response)
        try requireResponseStorageKey(response, expected: normalizedStorageKey)
        guard try requiredString(response, name: "credentialId") == normalizedCredentialId else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        return try PasskeyBackupCredentialRevokeResult(
            storageKey: normalizedStorageKey,
            credentialId: normalizedCredentialId,
            remainingCredentials: requiredInt(response, name: "remainingCredentials"),
            schemaVersion: requiredInt(response, name: "schemaVersion")
        )
    }

    func revokeAllCredentials(storageKey: String) async throws -> PasskeyBackupCredentialRevokeResult {
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let response = try await post(
            path: PasskeyBackupAuthorizationRequest.credentialsRevokeAllPath,
            body: lifecycleBody(storageKey: normalizedStorageKey)
        )
        try requireRelyingPartyId(response)
        try requireResponseStorageKey(response, expected: normalizedStorageKey)
        let remainingCredentials = try requiredInt(response, name: "remainingCredentials")
        guard remainingCredentials == 0 else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        return try PasskeyBackupCredentialRevokeResult(
            storageKey: normalizedStorageKey,
            credentialId: nil,
            remainingCredentials: remainingCredentials,
            schemaVersion: requiredInt(response, name: "schemaVersion")
        )
    }

    private func lifecycleBody(storageKey: String) -> [String: Any] {
        [
            "storageKey": storageKey,
            "rpId": PasskeyBackupContract.PASSKEY_RP_ID,
            "schemaVersion": PasskeyBackupContract.schemaVersion
        ]
    }

    private func requireResponseStorageKey(
        _ response: [String: Any],
        expected: String
    ) throws {
        guard try PasskeyBackupContract.validateStorageKey(
            requiredString(response, name: "storageKey")
        ) == expected else {
            throw PasskeyBackupError.mismatchedChallengeStorageKey
        }
    }
}

struct PasskeyBackupEncryptedRecord: Equatable {
    let storageKey: String
    let walletId: String
    let accountName: String
    let createdAtMillis: Int64
    let encryptedPayload: Data
    let schemaVersion: Int

    init(
        storageKey: String,
        walletId: String,
        accountName: String,
        createdAtMillis: Int64,
        encryptedPayload: Data,
        schemaVersion: Int = PasskeyBackupContract.schemaVersion
    ) throws {
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        self.walletId = try PasskeyBackupContract.validateWalletId(walletId)
        self.accountName = try PasskeyBackupContract.validateAccountName(accountName)
        self.createdAtMillis = try PasskeyBackupContract.validateCreatedAtMillis(
            createdAtMillis
        )

        guard !encryptedPayload.isEmpty else {
            throw PasskeyBackupError.emptyEncryptedPayload
        }

        try PasskeyBackupEnvelopeV1Format.validateCanonicalEnvelope(encryptedPayload)

        guard schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.unsupportedSchemaVersion(schemaVersion)
        }

        self.encryptedPayload = encryptedPayload
        self.schemaVersion = schemaVersion
    }

    func cloudKitRecordID() throws -> CKRecord.ID {
        CKRecord.ID(recordName: try PasskeyBackupContract.validateStorageKey(storageKey))
    }

    func envelopeMetadata() throws -> PasskeyBackupEnvelopeMetadata {
        try PasskeyBackupEnvelopeMetadata(
            storageKey: storageKey,
            walletId: walletId,
            accountName: accountName,
            createdAtMillis: createdAtMillis,
            schemaVersion: schemaVersion
        )
    }
}

protocol PasskeyBackupCloudStorage {
    func savePasskeyBackup(_ record: PasskeyBackupEncryptedRecord) async throws
    func loadPasskeyBackup(storageKey: String) async throws -> PasskeyBackupEncryptedRecord?
    func deletePasskeyBackup(storageKey: String) async throws
}

protocol PasskeyBackupCloudKitDatabase {
    func saveRecord(_ record: CKRecord) async throws
    func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord?
    func deleteRecord(recordID: CKRecord.ID) async throws
}

protocol PasskeyBackupCloudKitAccountStatusProvider {
    func accountStatus() async throws -> CKAccountStatus
}

final class UnavailablePasskeyBackupCloudStorage: PasskeyBackupCloudStorage {
    func savePasskeyBackup(_: PasskeyBackupEncryptedRecord) async throws {
        throw PasskeyBackupError.unavailableCloudStorage
    }

    func loadPasskeyBackup(storageKey _: String) async throws -> PasskeyBackupEncryptedRecord? {
        throw PasskeyBackupError.unavailableCloudStorage
    }

    func deletePasskeyBackup(storageKey _: String) async throws {
        throw PasskeyBackupError.unavailableCloudStorage
    }
}

final class SystemPasskeyBackupCloudKitDatabase: PasskeyBackupCloudKitDatabase {
    private let database: CKDatabase

    init(database: CKDatabase = CKContainer.default().privateCloudDatabase) {
        self.database = database
    }

    func saveRecord(_ record: CKRecord) async throws {
        _ = try await database.save(record)
    }

    func fetchRecord(recordID: CKRecord.ID) async throws -> CKRecord? {
        do {
            return try await database.record(for: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    func deleteRecord(recordID: CKRecord.ID) async throws {
        do {
            _ = try await database.deleteRecord(withID: recordID)
        } catch let error as CKError where error.code == .unknownItem {
            return
        }
    }
}

final class SystemPasskeyBackupCloudKitAccountStatusProvider: PasskeyBackupCloudKitAccountStatusProvider {
    private let container: CKContainer

    init(container: CKContainer = CKContainer.default()) {
        self.container = container
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await withCheckedThrowingContinuation { continuation in
            container.accountStatus { status, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }
}

final class CloudKitPasskeyBackupCloudStorage: PasskeyBackupCloudStorage {
    static let recordType = "FearlessPasskeyBackup"
    static let storageKeyField = "storageKey"
    static let walletIdField = "walletId"
    static let accountNameField = "accountName"
    static let createdAtMillisField = "createdAtMillis"
    static let encryptedPayloadField = "encryptedPayload"
    static let schemaVersionField = "schemaVersion"
    static let updatedAtField = "updatedAt"

    private let database: PasskeyBackupCloudKitDatabase
    private let accountStatusProvider: PasskeyBackupCloudKitAccountStatusProvider

    init(
        database: PasskeyBackupCloudKitDatabase = SystemPasskeyBackupCloudKitDatabase(),
        accountStatusProvider: PasskeyBackupCloudKitAccountStatusProvider =
            SystemPasskeyBackupCloudKitAccountStatusProvider()
    ) {
        self.database = database
        self.accountStatusProvider = accountStatusProvider
    }

    func savePasskeyBackup(_ record: PasskeyBackupEncryptedRecord) async throws {
        try await requireAvailableCloudKitAccount()

        let cloudRecord = CKRecord(
            recordType: Self.recordType,
            recordID: try record.cloudKitRecordID()
        )
        cloudRecord[Self.storageKeyField] = record.storageKey as NSString
        cloudRecord[Self.walletIdField] = record.walletId as NSString
        cloudRecord[Self.accountNameField] = record.accountName as NSString
        cloudRecord[Self.createdAtMillisField] = NSNumber(value: record.createdAtMillis)
        cloudRecord[Self.encryptedPayloadField] = record.encryptedPayload as NSData
        cloudRecord[Self.schemaVersionField] = NSNumber(value: record.schemaVersion)
        cloudRecord[Self.updatedAtField] = Date() as NSDate

        try await database.saveRecord(cloudRecord)
    }

    func loadPasskeyBackup(storageKey: String) async throws -> PasskeyBackupEncryptedRecord? {
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        try await requireAvailableCloudKitAccount()
        let recordID = CKRecord.ID(recordName: normalizedStorageKey)

        guard let cloudRecord = try await database.fetchRecord(recordID: recordID) else {
            return nil
        }

        guard cloudRecord.recordType == Self.recordType else {
            throw PasskeyBackupError.invalidCloudKitRecordType(cloudRecord.recordType)
        }

        guard let encryptedPayload = encryptedPayload(from: cloudRecord) else {
            throw PasskeyBackupError.missingCloudKitEncryptedPayload
        }

        let metadataStorageKey = try PasskeyBackupContract.validateStorageKey(
            stringField(Self.storageKeyField, from: cloudRecord)
        )
        guard metadataStorageKey == normalizedStorageKey else {
            throw PasskeyBackupError.invalidStorageKey
        }
        let walletId = try PasskeyBackupContract.validateWalletId(
            stringField(Self.walletIdField, from: cloudRecord)
        )
        let accountName = try PasskeyBackupContract.validateAccountName(
            stringField(Self.accountNameField, from: cloudRecord)
        )
        let createdAtMillis = try PasskeyBackupContract.validateCreatedAtMillis(
            int64Field(Self.createdAtMillisField, from: cloudRecord)
        )
        let schemaVersion = (cloudRecord[Self.schemaVersionField] as? NSNumber)?.intValue ??
            PasskeyBackupContract.schemaVersion

        return try PasskeyBackupEncryptedRecord(
            storageKey: normalizedStorageKey,
            walletId: walletId,
            accountName: accountName,
            createdAtMillis: createdAtMillis,
            encryptedPayload: encryptedPayload,
            schemaVersion: schemaVersion
        )
    }

    func deletePasskeyBackup(storageKey: String) async throws {
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        try await requireAvailableCloudKitAccount()
        try await database.deleteRecord(recordID: CKRecord.ID(recordName: normalizedStorageKey))
    }

    private func requireAvailableCloudKitAccount() async throws {
        guard try await accountStatusProvider.accountStatus() == .available else {
            throw PasskeyBackupError.unavailableCloudKitAccount
        }
    }

    private func encryptedPayload(from record: CKRecord) -> Data? {
        if let payload = record[Self.encryptedPayloadField] as? Data {
            return payload
        }

        if let payload = record[Self.encryptedPayloadField] as? NSData {
            return payload as Data
        }

        return nil
    }

    private func stringField(_ field: String, from record: CKRecord) throws -> String {
        let rawValue: String?
        if let value = record[field] as? String {
            rawValue = value
        } else if let value = record[field] as? NSString {
            rawValue = value as String
        } else {
            rawValue = nil
        }

        guard let value = rawValue,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return value
    }

    private func int64Field(_ field: String, from record: CKRecord) throws -> Int64 {
        guard let value = record[field] as? NSNumber else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return value.int64Value
    }
}

struct PendingPasskeyBackupRegistration: Equatable {
    let registrationId: String
    let storageKey: String
    let walletId: String
    let accountName: String
    let challenge: Data
    let userId: Data
    let userName: String
    let displayName: String

    init(
        challenge: PasskeyBackupRegistrationChallenge,
        walletId: String,
        accountName: String
    ) throws {
        registrationId = challenge.registrationId
        storageKey = challenge.storageKey
        self.walletId = try PasskeyBackupContract.validateWalletId(walletId)
        self.accountName = try PasskeyBackupContract.validateAccountName(accountName)
        self.challenge = challenge.challenge
        userId = challenge.userId
        userName = challenge.userName
        displayName = challenge.displayName
    }
}

struct PendingPasskeyBackupAssertion: Equatable {
    let assertionId: String
    let storageKey: String
    let challenge: Data

    init(challenge: PasskeyBackupAssertionChallenge) {
        assertionId = challenge.assertionId
        storageKey = challenge.storageKey
        self.challenge = challenge.challenge
    }
}

private enum PasskeyBackupRegistrationCompensationOutcome {
    case succeeded
    case revokeFailed(Error)
    case timedOut
}

private actor PasskeyBackupCompensationLatch {
    private var outcome: PasskeyBackupRegistrationCompensationOutcome?
    private var waiters: [
        CheckedContinuation<PasskeyBackupRegistrationCompensationOutcome, Never>
    ] = []

    func wait() async -> PasskeyBackupRegistrationCompensationOutcome {
        if let outcome {
            return outcome
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func finish(_ outcome: PasskeyBackupRegistrationCompensationOutcome) {
        guard self.outcome == nil else {
            return
        }
        self.outcome = outcome
        let pendingWaiters = waiters
        waiters.removeAll()
        pendingWaiters.forEach { $0.resume(returning: outcome) }
    }
}

final class PasskeyBackupWorkflow {
    private let challengeService: PasskeyBackupChallengeService
    private let cloudStorage: PasskeyBackupCloudStorage
    private let backupKeyProvider: RecoverablePasskeyBackupKeyProvider
    private let envelopeCryptography: PasskeyBackupEnvelopeCryptography
    private let isReleaseEnabled: Bool
    private let createdAtMillisProvider: () -> Int64
    private let compensationTimeoutNanoseconds: UInt64

    init(
        challengeService: PasskeyBackupChallengeService,
        cloudStorage: PasskeyBackupCloudStorage,
        backupKeyProvider: RecoverablePasskeyBackupKeyProvider =
            UnavailablePasskeyBackupKeyProvider(),
        envelopeCryptography: PasskeyBackupEnvelopeCryptography =
            AESGCMPasskeyBackupEnvelopeCryptography(),
        relyingPartyId: String = PasskeyBackupContract.PASSKEY_RP_ID,
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        compensationTimeoutNanoseconds: UInt64 = 5_000_000_000,
        createdAtMillisProvider: @escaping () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1000)
        }
    ) throws {
        guard (1_000_000 ... 30_000_000_000).contains(compensationTimeoutNanoseconds) else {
            throw PasskeyBackupError.invalidCompensationTimeout
        }
        try PasskeyBackupContract.validateRelyingPartyId(relyingPartyId)
        self.challengeService = challengeService
        self.cloudStorage = cloudStorage
        self.backupKeyProvider = backupKeyProvider
        self.envelopeCryptography = envelopeCryptography
        self.isReleaseEnabled = isReleaseEnabled
        self.compensationTimeoutNanoseconds = compensationTimeoutNanoseconds
        self.createdAtMillisProvider = createdAtMillisProvider
    }

    func beginRegistration(
        walletId: String,
        accountName: String,
        displayName: String
    ) async throws -> PendingPasskeyBackupRegistration {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let normalizedWalletId = try PasskeyBackupContract.validateWalletId(walletId)
        let selectedAccountName = try PasskeyBackupContract.validateAccountName(accountName)
        let challenge = try await challengeService.registrationChallenge(
            walletId: normalizedWalletId,
            accountName: selectedAccountName,
            displayName: displayName
        )
        _ = try PasskeyBackupContract.validateMatchingAccountName(
            expected: selectedAccountName,
            actual: challenge.userName
        )

        return try PendingPasskeyBackupRegistration(
            challenge: challenge,
            walletId: normalizedWalletId,
            accountName: selectedAccountName
        )
    }

    func finishRegistrationWithEncryptedRecord(
        pending: PendingPasskeyBackupRegistration,
        credentialResponseJSON: String,
        record: PasskeyBackupEncryptedRecord
    ) async throws -> PasskeyBackupEncryptedRecord {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let expectedStorageKey = try PasskeyBackupContract.validateStorageKey(pending.storageKey)
        guard record.storageKey == expectedStorageKey else {
            throw PasskeyBackupError.mismatchedChallengeStorageKey
        }
        guard record.walletId == pending.walletId else {
            throw PasskeyBackupError.invalidWalletId
        }
        guard record.accountName == pending.accountName else {
            throw PasskeyBackupError.invalidUserName
        }
        try await requireAuthenticatedEnvelope(record)
        let credentialId = try registrationCredentialId(credentialResponseJSON)

        var completionConfirmed = false
        return try await withRegistrationCompensation(
            storageKey: expectedStorageKey,
            credentialId: credentialId,
            shouldCompensate: { error in
                completionConfirmed ||
                    error as? PasskeyBackupError == .registrationCompletionOutcomeUnknown
            }
        ) {
            let result = try await self.challengeService.completeRegistration(
                registrationId: pending.registrationId,
                credentialResponseJSON: credentialResponseJSON
            )
            completionConfirmed = true
            _ = try self.requireMatchingStorageKey(
                expected: expectedStorageKey,
                actual: result.storageKey
            )
            try await self.cloudStorage.savePasskeyBackup(record)
            return record
        }
    }

    @available(
        *,
        deprecated,
        message: "Opaque ciphertext cannot be authenticated without its original AAD metadata; use finishRegistrationWithPlaintext or finishRegistrationWithEncryptedRecord"
    )
    func finishRegistration(
        pending _: PendingPasskeyBackupRegistration,
        credentialResponseJSON _: String,
        encryptedPayload _: Data
    ) async throws -> PasskeyBackupEncryptedRecord {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        throw PasskeyBackupError.encryptedPayloadMetadataRequired
    }

    func finishRegistrationWithPlaintext(
        pending: PendingPasskeyBackupRegistration,
        credentialResponseJSON: String,
        plaintextBackup: Data
    ) async throws -> PasskeyBackupEncryptedRecord {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let expectedStorageKey = try PasskeyBackupContract.validateStorageKey(pending.storageKey)
        let metadata = try PasskeyBackupEnvelopeMetadata(
            storageKey: expectedStorageKey,
            walletId: pending.walletId,
            accountName: pending.accountName,
            createdAtMillis: createdAtMillisProvider()
        )
        let envelope: Data
        do {
            var key = try await backupKeyProvider.backupKey(for: metadata)
            defer { key.resetBytes(in: 0 ..< key.count) }
            envelope = try envelopeCryptography.encrypt(
                plaintextBackup,
                metadata: metadata,
                key: key
            )
        }
        let record = try PasskeyBackupEncryptedRecord(
            storageKey: metadata.storageKey,
            walletId: metadata.walletId,
            accountName: metadata.accountName,
            createdAtMillis: metadata.createdAtMillis,
            encryptedPayload: envelope,
            schemaVersion: metadata.schemaVersion
        )
        let credentialId = try registrationCredentialId(credentialResponseJSON)

        var completionConfirmed = false
        return try await withRegistrationCompensation(
            storageKey: expectedStorageKey,
            credentialId: credentialId,
            shouldCompensate: { error in
                completionConfirmed ||
                    error as? PasskeyBackupError == .registrationCompletionOutcomeUnknown
            }
        ) {
            let result = try await self.challengeService.completeRegistration(
                registrationId: pending.registrationId,
                credentialResponseJSON: credentialResponseJSON
            )
            completionConfirmed = true
            _ = try self.requireMatchingStorageKey(
                expected: expectedStorageKey,
                actual: result.storageKey
            )
            try await self.cloudStorage.savePasskeyBackup(record)
            return record
        }
    }

    func beginRestore(storageKey: String) async throws -> PendingPasskeyBackupAssertion {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let challenge = try await challengeService.assertionChallenge(storageKey: normalizedStorageKey)
        _ = try requireMatchingStorageKey(
            expected: normalizedStorageKey,
            actual: challenge.storageKey
        )

        return PendingPasskeyBackupAssertion(challenge: challenge)
    }

    func finishRestore(
        pending: PendingPasskeyBackupAssertion,
        credentialResponseJSON: String
    ) async throws -> PasskeyBackupEncryptedRecord {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let result = try await challengeService.completeAssertion(
            assertionId: pending.assertionId,
            credentialResponseJSON: credentialResponseJSON
        )
        let storageKey = try requireMatchingStorageKey(
            expected: pending.storageKey,
            actual: result.storageKey
        )

        guard let record = try await cloudStorage.loadPasskeyBackup(storageKey: storageKey) else {
            throw PasskeyBackupError.missingCloudBackup
        }

        return record
    }

    func finishRestoreWithDecryption(
        pending: PendingPasskeyBackupAssertion,
        credentialResponseJSON: String
    ) async throws -> Data {
        let record = try await finishRestore(
            pending: pending,
            credentialResponseJSON: credentialResponseJSON
        )
        let metadata = try record.envelopeMetadata()
        var key = try await backupKeyProvider.backupKey(for: metadata)
        defer { key.resetBytes(in: 0 ..< key.count) }
        return try envelopeCryptography.decrypt(
            record.encryptedPayload,
            metadata: metadata,
            key: key
        )
    }

    func listCredentials(storageKey: String) async throws -> PasskeyBackupCredentialListResult {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let result = try await challengeService.listCredentials(storageKey: normalizedStorageKey)
        _ = try requireMatchingStorageKey(
            expected: normalizedStorageKey,
            actual: result.storageKey
        )
        return result
    }

    func revokeCredential(
        storageKey: String,
        credentialId: String
    ) async throws -> PasskeyBackupCredentialRevokeResult {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let normalizedCredentialId = try PasskeyBackupContract.validateCredentialId(credentialId)
        let result = try await challengeService.revokeCredential(
            storageKey: normalizedStorageKey,
            credentialId: normalizedCredentialId
        )
        _ = try requireMatchingStorageKey(
            expected: normalizedStorageKey,
            actual: result.storageKey
        )
        guard result.credentialId == normalizedCredentialId else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        return result
    }

    func deleteBackup(storageKey: String) async throws {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let revoked = try await challengeService.revokeAllCredentials(storageKey: normalizedStorageKey)
        guard revoked.storageKey == normalizedStorageKey,
              revoked.credentialId == nil,
              revoked.remainingCredentials == 0 else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        try await cloudStorage.deletePasskeyBackup(
            storageKey: normalizedStorageKey
        )
    }

    private func requireMatchingStorageKey(
        expected: String,
        actual: String
    ) throws -> String {
        let normalizedExpected = try PasskeyBackupContract.validateStorageKey(expected)
        let normalizedActual = try PasskeyBackupContract.validateStorageKey(actual)

        guard normalizedActual == normalizedExpected else {
            throw PasskeyBackupError.mismatchedChallengeStorageKey
        }

        return normalizedActual
    }

    private func registrationCredentialId(_ credentialResponseJSON: String) throws -> String {
        guard let data = credentialResponseJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let id = root["id"] as? String else {
            throw PasskeyBackupError.invalidCredentialResponse
        }
        return try PasskeyBackupContract.validateCredentialId(id)
    }

    private func requireAuthenticatedEnvelope(
        _ record: PasskeyBackupEncryptedRecord
    ) async throws {
        let metadata = try record.envelopeMetadata()
        var key = try await backupKeyProvider.backupKey(for: metadata)
        defer { key.resetBytes(in: 0 ..< key.count) }
        var plaintext = try envelopeCryptography.decrypt(
            record.encryptedPayload,
            metadata: metadata,
            key: key
        )
        plaintext.resetBytes(in: 0 ..< plaintext.count)
    }
}

private extension PasskeyBackupWorkflow {
    func withRegistrationCompensation<T>(
        storageKey: String,
        credentialId: String,
        shouldCompensate: (Error) -> Bool,
        operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            let operationError = error
            if shouldCompensate(operationError) {
                let outcome = await attemptRegistrationCompensation(
                    storageKey: storageKey,
                    credentialId: credentialId
                )
                switch outcome {
                case .succeeded:
                    break
                case let .revokeFailed(cleanupError):
                    throw PasskeyBackupRegistrationCompensationError(
                        primaryError: operationError,
                        failureKind: .revokeFailed,
                        cleanupError: cleanupError
                    )
                case .timedOut:
                    throw PasskeyBackupRegistrationCompensationError(
                        primaryError: operationError,
                        failureKind: .timedOut,
                        cleanupError: nil
                    )
                }
            }
            throw operationError
        }
    }

    func attemptRegistrationCompensation(
        storageKey: String,
        credentialId: String
    ) async -> PasskeyBackupRegistrationCompensationOutcome {
        let latch = PasskeyBackupCompensationLatch()
        let challengeService = challengeService
        let timeout = compensationTimeoutNanoseconds
        // Unstructured tasks have independent cancellation while retaining the
        // current actor context. This gives revoke a fresh opportunity without
        // an unsafe detached capture when the registration task is cancelled.
        let revokeTask = Task {
            do {
                let result = try await challengeService.revokeCredential(
                    storageKey: storageKey,
                    credentialId: credentialId
                )
                guard result.storageKey == storageKey,
                      result.credentialId == credentialId else {
                    throw PasskeyBackupError.malformedChallengeServiceResponse
                }
                await latch.finish(.succeeded)
            } catch {
                await latch.finish(.revokeFailed(error))
            }
        }
        let timeoutTask = Task {
            do {
                try await Task.sleep(nanoseconds: timeout)
            } catch {
                return
            }
            await latch.finish(.timedOut)
        }

        let outcome = await latch.wait()
        revokeTask.cancel()
        timeoutTask.cancel()
        return outcome
    }
}

@available(iOS 15.0, *)
final class PasskeyBackupCoordinator {
    let relyingPartyId: String

    private let provider: ASAuthorizationPlatformPublicKeyCredentialProvider
    private let cloudStorage: PasskeyBackupCloudStorage
    private let challengeService: PasskeyBackupChallengeService?
    private let backupKeyProvider: RecoverablePasskeyBackupKeyProvider
    private let envelopeCryptography: PasskeyBackupEnvelopeCryptography
    private let isReleaseEnabled: Bool

    init(
        relyingPartyId: String = PasskeyBackupContract.PASSKEY_RP_ID,
        cloudStorage: PasskeyBackupCloudStorage = UnavailablePasskeyBackupCloudStorage(),
        challengeService: PasskeyBackupChallengeService? = nil,
        backupKeyProvider: RecoverablePasskeyBackupKeyProvider =
            UnavailablePasskeyBackupKeyProvider(),
        envelopeCryptography: PasskeyBackupEnvelopeCryptography =
            AESGCMPasskeyBackupEnvelopeCryptography(),
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled
    ) throws {
        try PasskeyBackupContract.validateRelyingPartyId(relyingPartyId)

        self.relyingPartyId = relyingPartyId
        provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyId
        )
        self.cloudStorage = cloudStorage
        self.challengeService = challengeService
        self.backupKeyProvider = backupKeyProvider
        self.envelopeCryptography = envelopeCryptography
        self.isReleaseEnabled = isReleaseEnabled
    }

    func registrationRequest(
        challenge: Data,
        userId: Data,
        userName: String,
        displayName: String
    ) throws -> ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try PasskeyBackupContract.validateChallenge(challenge)
        try PasskeyBackupContract.validateUserId(userId)

        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDisplayName.isEmpty, normalizedDisplayName.count <= 128 else {
            throw PasskeyBackupError.invalidDisplayName
        }

        return provider.createCredentialRegistrationRequest(
            challenge: challenge,
            name: try PasskeyBackupContract.validateAccountName(userName),
            userID: userId
        )
    }

    func assertionRequest(
        challenge: Data
    ) throws -> ASAuthorizationPlatformPublicKeyCredentialAssertionRequest {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try PasskeyBackupContract.validateChallenge(challenge)
        return provider.createCredentialAssertionRequest(challenge: challenge)
    }

    func saveEncryptedCloudBackup(_ record: PasskeyBackupEncryptedRecord) async throws {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try await requireAuthenticatedEnvelope(record)
        try await cloudStorage.savePasskeyBackup(record)
    }

    func loadEncryptedCloudBackup(storageKey: String) async throws -> PasskeyBackupEncryptedRecord? {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        guard let record = try await cloudStorage.loadPasskeyBackup(
            storageKey: try PasskeyBackupContract.validateStorageKey(storageKey)
        ) else {
            return nil
        }
        try await requireAuthenticatedEnvelope(record)
        return record
    }

    func deleteEncryptedCloudBackup(storageKey: String) async throws {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        guard let challengeService else {
            throw PasskeyBackupError.unavailableAuthorization
        }
        let revoked = try await challengeService.revokeAllCredentials(storageKey: normalizedStorageKey)
        guard revoked.storageKey == normalizedStorageKey,
              revoked.credentialId == nil,
              revoked.remainingCredentials == 0 else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }
        try await cloudStorage.deletePasskeyBackup(
            storageKey: normalizedStorageKey
        )
    }

    private func requireAuthenticatedEnvelope(
        _ record: PasskeyBackupEncryptedRecord
    ) async throws {
        let metadata = try record.envelopeMetadata()
        var key = try await backupKeyProvider.backupKey(for: metadata)
        defer { key.resetBytes(in: 0 ..< key.count) }
        var plaintext = try envelopeCryptography.decrypt(
            record.encryptedPayload,
            metadata: metadata,
            key: key
        )
        plaintext.resetBytes(in: 0 ..< plaintext.count)
    }
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
protocol PasskeyBackupCeremonyExecutor {
    func performRegistration(_ pending: PendingPasskeyBackupRegistration) async throws -> String
    func performAssertion(_ pending: PendingPasskeyBackupAssertion) async throws -> String
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class ASPasskeyBackupCeremonyExecutor: NSObject,
    PasskeyBackupCeremonyExecutor,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private enum Ceremony {
        case registration
        case assertion
    }

    private let provider: ASAuthorizationPlatformPublicKeyCredentialProvider
    private let presentationAnchorProvider: () -> ASPresentationAnchor
    private let isReleaseEnabled: Bool
    private var activeController: ASAuthorizationController?
    private var activeCeremony: Ceremony?
    private var continuation: CheckedContinuation<String, Error>?

    init(
        relyingPartyId: String = PasskeyBackupContract.PASSKEY_RP_ID,
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        presentationAnchorProvider: @escaping () -> ASPresentationAnchor
    ) throws {
        try PasskeyBackupContract.validateRelyingPartyId(relyingPartyId)
        provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyId
        )
        self.isReleaseEnabled = isReleaseEnabled
        self.presentationAnchorProvider = presentationAnchorProvider
    }

    func performRegistration(_ pending: PendingPasskeyBackupRegistration) async throws -> String {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try PasskeyBackupContract.validateChallenge(pending.challenge)
        try PasskeyBackupContract.validateUserId(pending.userId)
        let request = provider.createCredentialRegistrationRequest(
            challenge: pending.challenge,
            name: try PasskeyBackupContract.validateAccountName(pending.userName),
            userID: pending.userId
        )
        request.displayName = pending.displayName
        request.userVerificationPreference = .required
        request.attestationPreference = .none
        return try await authorize(request: request, ceremony: .registration)
    }

    func performAssertion(_ pending: PendingPasskeyBackupAssertion) async throws -> String {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try PasskeyBackupContract.validateChallenge(pending.challenge)
        let request = provider.createCredentialAssertionRequest(challenge: pending.challenge)
        request.allowedCredentials = []
        request.userVerificationPreference = .required
        return try await authorize(request: request, ceremony: .assertion)
    }

    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        presentationAnchorProvider()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard controller === activeController, let ceremony = activeCeremony else {
            return
        }

        do {
            let response: String
            switch (ceremony, authorization.credential) {
            case let (.registration, credential as ASAuthorizationPlatformPublicKeyCredentialRegistration):
                response = try PasskeyCredentialResponseSerializer.registrationJSON(for: credential)
            case let (.assertion, credential as ASAuthorizationPlatformPublicKeyCredentialAssertion):
                response = try PasskeyCredentialResponseSerializer.assertionJSON(for: credential)
            default:
                throw PasskeyBackupError.unexpectedCredentialType
            }
            finish(.success(response))
        } catch {
            finish(.failure(error))
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        guard controller === activeController else {
            return
        }
        finish(.failure(error))
    }

    private func authorize(
        request: ASAuthorizationRequest,
        ceremony: Ceremony
    ) async throws -> String {
        try Task.checkCancellation()
        guard continuation == nil else {
            throw PasskeyBackupError.ceremonyInProgress
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let controller = ASAuthorizationController(authorizationRequests: [request])
                self.continuation = continuation
                activeCeremony = ceremony
                activeController = controller
                controller.delegate = self
                controller.presentationContextProvider = self
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finish(.failure(PasskeyBackupError.ceremonyCancelled))
            }
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else {
            return
        }
        self.continuation = nil
        activeController = nil
        activeCeremony = nil
        continuation.resume(with: result)
    }
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
final class PasskeyBackupClient {
    private let workflow: PasskeyBackupWorkflow
    private let ceremonyExecutor: PasskeyBackupCeremonyExecutor
    private let isReleaseEnabled: Bool

    init(
        workflow: PasskeyBackupWorkflow,
        ceremonyExecutor: PasskeyBackupCeremonyExecutor,
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled
    ) {
        self.workflow = workflow
        self.ceremonyExecutor = ceremonyExecutor
        self.isReleaseEnabled = isReleaseEnabled
    }

    func registerBackup(
        walletId: String,
        accountName: String,
        displayName: String,
        plaintextBackup: Data
    ) async throws -> PasskeyBackupEncryptedRecord {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let pending = try await workflow.beginRegistration(
            walletId: walletId,
            accountName: accountName,
            displayName: displayName
        )
        let response = try await ceremonyExecutor.performRegistration(pending)
        return try await workflow.finishRegistrationWithPlaintext(
            pending: pending,
            credentialResponseJSON: response,
            plaintextBackup: plaintextBackup
        )
    }

    func restoreBackup(storageKey: String) async throws -> Data {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let pending = try await workflow.beginRestore(storageKey: storageKey)
        let response = try await ceremonyExecutor.performAssertion(pending)
        return try await workflow.finishRestoreWithDecryption(
            pending: pending,
            credentialResponseJSON: response
        )
    }

    func listCredentials(storageKey: String) async throws -> PasskeyBackupCredentialListResult {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        return try await workflow.listCredentials(storageKey: storageKey)
    }

    func revokeCredential(
        storageKey: String,
        credentialId: String
    ) async throws -> PasskeyBackupCredentialRevokeResult {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        return try await workflow.revokeCredential(
            storageKey: storageKey,
            credentialId: credentialId
        )
    }

    func deleteBackup(storageKey: String) async throws {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try await workflow.deleteBackup(storageKey: storageKey)
    }
}

@available(iOS 15.0, macOS 12.0, *)
@MainActor
enum PasskeyBackupComposition {
    static func makeClient(
        challengeService: PasskeyBackupChallengeService,
        cloudStorage: PasskeyBackupCloudStorage,
        backupKeyProvider: RecoverablePasskeyBackupKeyProvider =
            UnavailablePasskeyBackupKeyProvider(),
        envelopeCryptography: PasskeyBackupEnvelopeCryptography =
            AESGCMPasskeyBackupEnvelopeCryptography(),
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        presentationAnchorProvider: @escaping () -> ASPresentationAnchor
    ) throws -> PasskeyBackupClient {
        let workflow = try PasskeyBackupWorkflow(
            challengeService: challengeService,
            cloudStorage: cloudStorage,
            backupKeyProvider: backupKeyProvider,
            envelopeCryptography: envelopeCryptography,
            isReleaseEnabled: isReleaseEnabled
        )
        let executor = try ASPasskeyBackupCeremonyExecutor(
            isReleaseEnabled: isReleaseEnabled,
            presentationAnchorProvider: presentationAnchorProvider
        )
        return PasskeyBackupClient(
            workflow: workflow,
            ceremonyExecutor: executor,
            isReleaseEnabled: isReleaseEnabled
        )
    }
}
