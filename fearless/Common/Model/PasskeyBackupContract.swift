import AuthenticationServices
import CloudKit
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
    case mismatchedChallengeStorageKey
    case missingCloudBackup
    case passkeyBackupDisabled
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
        guard (16 ... 64).contains(userId.count) else {
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
              normalized.contains("@") else {
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

    static func decodeBase64URL(_ value: String) throws -> Data {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        var base64 = normalized
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

        guard let data = Data(base64Encoded: base64) else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return data
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
        guard !normalizedDisplayName.isEmpty else {
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

@available(iOS 15.0, macOS 12.0, *)
final class URLSessionPasskeyBackupHTTPTransport: PasskeyBackupHTTPTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func execute(_ request: PasskeyBackupHTTPRequest) async throws -> PasskeyBackupHTTPResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        urlRequest.httpBody = request.body

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return PasskeyBackupHTTPResponse(statusCode: httpResponse.statusCode, body: data)
    }
}

final class HTTPPasskeyBackupChallengeService: PasskeyBackupChallengeService {
    private static let registrationChallengePath = "/api/passkey-backup/v1/registration/challenge"
    private static let registrationCompletePath = "/api/passkey-backup/v1/registration/complete"
    private static let assertionChallengePath = "/api/passkey-backup/v1/assertion/challenge"
    private static let assertionCompletePath = "/api/passkey-backup/v1/assertion/complete"

    private let baseURL: URL
    private let transport: PasskeyBackupHTTPTransport

    convenience init(baseURL: String, transport: PasskeyBackupHTTPTransport) throws {
        let normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: normalized) else {
            throw PasskeyBackupError.invalidChallengeServiceURL(baseURL)
        }

        try self.init(baseURL: url, transport: transport)
    }

    init(baseURL: URL, transport: PasskeyBackupHTTPTransport) throws {
        self.baseURL = try Self.normalizedBaseURL(baseURL)
        self.transport = transport
    }

    @available(iOS 15.0, macOS 12.0, *)
    convenience init(baseURL: String) throws {
        try self.init(baseURL: baseURL, transport: URLSessionPasskeyBackupHTTPTransport())
    }

    func registrationChallenge(
        walletId: String,
        accountName: String,
        displayName: String
    ) async throws -> PasskeyBackupRegistrationChallenge {
        let normalizedWalletId = try PasskeyBackupContract.validateWalletId(walletId)
        let normalizedAccountName = try PasskeyBackupContract.validateAccountName(accountName)
        let normalizedDisplayName = try Self.requiredLocalString(displayName)

        let response = try await post(
            path: Self.registrationChallengePath,
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
            path: Self.registrationCompletePath,
            body: [
                "registrationId": try PasskeyBackupContract.validateCeremonyId(registrationId),
                "rpId": PasskeyBackupContract.PASSKEY_RP_ID,
                "credential": try credentialJSONObject(credentialResponseJSON)
            ]
        )

        return try challengeResult(response)
    }

    func assertionChallenge(storageKey: String) async throws -> PasskeyBackupAssertionChallenge {
        let normalizedStorageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let response = try await post(
            path: Self.assertionChallengePath,
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
            path: Self.assertionCompletePath,
            body: [
                "assertionId": try PasskeyBackupContract.validateCeremonyId(assertionId),
                "rpId": PasskeyBackupContract.PASSKEY_RP_ID,
                "credential": try credentialJSONObject(credentialResponseJSON)
            ]
        )

        return try challengeResult(response)
    }

    private func post(path: String, body: [String: Any]) async throws -> [String: Any] {
        let requestBody = try JSONSerialization.data(withJSONObject: body, options: [])
        let response = try await transport.execute(
            PasskeyBackupHTTPRequest(
                method: "POST",
                url: endpoint(path: path),
                headers: ["Content-Type": "application/json; charset=utf-8"],
                body: requestBody
            )
        )

        guard (200 ... 299).contains(response.statusCode) else {
            throw PasskeyBackupError.challengeServiceHTTPStatus(response.statusCode)
        }

        guard !response.body.isEmpty else {
            throw PasskeyBackupError.emptyChallengeServiceResponse
        }

        do {
            guard let root = try JSONSerialization.jsonObject(with: response.body) as? [String: Any] else {
                throw PasskeyBackupError.malformedChallengeServiceResponse
            }

            return root
        } catch let error as PasskeyBackupError {
            throw error
        } catch {
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
              String(cString: value.objCType) != "c" else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return value.intValue
    }

    private static func requiredLocalString(_ value: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw PasskeyBackupError.malformedChallengeServiceResponse
        }

        return normalized
    }

    private static func normalizedBaseURL(_ url: URL) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https",
              !(components.host ?? "").isEmpty,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil else {
            throw PasskeyBackupError.invalidChallengeServiceURL(url.absoluteString)
        }

        while components.percentEncodedPath.hasSuffix("/") {
            components.percentEncodedPath.removeLast()
        }

        guard let normalized = components.url else {
            throw PasskeyBackupError.invalidChallengeServiceURL(url.absoluteString)
        }

        return normalized
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

        guard schemaVersion == PasskeyBackupContract.schemaVersion else {
            throw PasskeyBackupError.unsupportedSchemaVersion(schemaVersion)
        }

        self.encryptedPayload = encryptedPayload
        self.schemaVersion = schemaVersion
    }

    func cloudKitRecordID() throws -> CKRecord.ID {
        CKRecord.ID(recordName: try PasskeyBackupContract.validateStorageKey(storageKey))
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

final class PasskeyBackupWorkflow {
    private let challengeService: PasskeyBackupChallengeService
    private let cloudStorage: PasskeyBackupCloudStorage
    private let isReleaseEnabled: Bool
    private let createdAtMillisProvider: () -> Int64

    init(
        challengeService: PasskeyBackupChallengeService,
        cloudStorage: PasskeyBackupCloudStorage,
        relyingPartyId: String = PasskeyBackupContract.PASSKEY_RP_ID,
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled,
        createdAtMillisProvider: @escaping () -> Int64 = {
            Int64(Date().timeIntervalSince1970 * 1000)
        }
    ) throws {
        try PasskeyBackupContract.validateRelyingPartyId(relyingPartyId)
        self.challengeService = challengeService
        self.cloudStorage = cloudStorage
        self.isReleaseEnabled = isReleaseEnabled
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

    func finishRegistration(
        pending: PendingPasskeyBackupRegistration,
        credentialResponseJSON: String,
        encryptedPayload: Data
    ) async throws -> PasskeyBackupEncryptedRecord {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        let result = try await challengeService.completeRegistration(
            registrationId: pending.registrationId,
            credentialResponseJSON: credentialResponseJSON
        )
        let storageKey = try requireMatchingStorageKey(
            expected: pending.storageKey,
            actual: result.storageKey
        )
        let record = try PasskeyBackupEncryptedRecord(
            storageKey: storageKey,
            walletId: pending.walletId,
            accountName: pending.accountName,
            createdAtMillis: createdAtMillisProvider(),
            encryptedPayload: encryptedPayload
        )

        try await cloudStorage.savePasskeyBackup(record)
        return record
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

    func deleteBackup(storageKey: String) async throws {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try await cloudStorage.deletePasskeyBackup(
            storageKey: try PasskeyBackupContract.validateStorageKey(storageKey)
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
}

@available(iOS 15.0, *)
final class PasskeyBackupCoordinator {
    let relyingPartyId: String

    private let provider: ASAuthorizationPlatformPublicKeyCredentialProvider
    private let cloudStorage: PasskeyBackupCloudStorage
    private let isReleaseEnabled: Bool

    init(
        relyingPartyId: String = PasskeyBackupContract.PASSKEY_RP_ID,
        cloudStorage: PasskeyBackupCloudStorage = UnavailablePasskeyBackupCloudStorage(),
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled
    ) throws {
        try PasskeyBackupContract.validateRelyingPartyId(relyingPartyId)

        self.relyingPartyId = relyingPartyId
        provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyId
        )
        self.cloudStorage = cloudStorage
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
        guard !normalizedDisplayName.isEmpty else {
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
        try await cloudStorage.savePasskeyBackup(record)
    }

    func loadEncryptedCloudBackup(storageKey: String) async throws -> PasskeyBackupEncryptedRecord? {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        return try await cloudStorage.loadPasskeyBackup(
            storageKey: try PasskeyBackupContract.validateStorageKey(storageKey)
        )
    }

    func deleteEncryptedCloudBackup(storageKey: String) async throws {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try await cloudStorage.deletePasskeyBackup(
            storageKey: try PasskeyBackupContract.validateStorageKey(storageKey)
        )
    }
}
