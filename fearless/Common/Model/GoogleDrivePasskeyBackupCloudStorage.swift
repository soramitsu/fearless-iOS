import Foundation
import UIKit

/// Portable ciphertext storage only. Google identity never authorizes wallet recovery.
final class GoogleDrivePasskeyBackupCloudStorage: PasskeyBackupCloudStorage {
    static let appDataScope = "https://www.googleapis.com/auth/drive.appdata"
    static let appDataFolder = "appDataFolder"
    private static let mimeType = "application/octet-stream"
    private static let baseURL = "https://www.googleapis.com/drive/v3/files"
    private static let uploadURL = "https://www.googleapis.com/upload/drive/v3/files"
    private let account: GoogleDriveBackupAccount
    private let tokenProvider: GoogleDriveBackupAccessTokenProvider
    private let transport: PasskeyBackupHTTPTransport
    private let now: () -> Date

    init(
        account: GoogleDriveBackupAccount,
        tokenProvider: GoogleDriveBackupAccessTokenProvider,
        transport: PasskeyBackupHTTPTransport,
        now: @escaping () -> Date = Date.init
    ) {
        self.account = account
        self.tokenProvider = tokenProvider
        self.transport = transport
        self.now = now
    }

    func savePasskeyBackup(_ record: PasskeyBackupEncryptedRecord) async throws {
        let properties = try Self.properties(record)
        guard record.encryptedPayload.count <= PasskeyBackupHTTPTransportPolicy.maximumResponseBytes else {
            throw GoogleDrivePasskeyBackupError.metadataTooLarge
        }
        let existing = try await findBackup(storageKey: record.storageKey)
        // The legacy single-file format remains readable. Replacing it could destroy the
        // last decryptable backup before an immutable generation is verified and promoted.
        guard existing == nil else { throw GoogleDrivePasskeyBackupError.immutableGenerationRequired }
        let metadata: [String: Any] = [
            "name": Self.fileName(record.storageKey),
            "mimeType": Self.mimeType,
            "appProperties": properties,
            "parents": [Self.appDataFolder]
        ]
        // A random boundary prevents arbitrary encrypted bytes from being interpreted as MIME delimiters.
        let boundary = "fearless-passkey-\(UUID().uuidString)"
        var body = Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8)
        body.append(try JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]))
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: \(Self.mimeType)\r\n\r\n".utf8))
        body.append(record.encryptedPayload)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let url = try Self.url(base: Self.uploadURL, query: ["uploadType": "multipart", "fields": "id,name,appProperties"])
        let response = try await execute(
            method: "POST", url: url,
            headers: ["Content-Type": "multipart/related; boundary=\(boundary)"], body: body
        )
        try Self.requireSuccess(response)
        let saved = try Self.decodeFile(
            JSONSerialization.jsonObject(with: response.body),
            storageKey: record.storageKey
        )
        guard saved.properties == properties else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
    }

    func loadPasskeyBackup(storageKey: String) async throws -> PasskeyBackupEncryptedRecord? {
        let storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        guard let file = try await findBackup(storageKey: storageKey) else { return nil }
        let response = try await execute(
            method: "GET", url: Self.url(base: Self.baseURL, fileID: file.id, query: ["alt": "media"])
        )
        if response.statusCode == 404 { return nil }
        try Self.requireSuccess(response)
        return try PasskeyBackupEncryptedRecord(
            storageKey: storageKey,
            walletId: file.properties["walletId"] ?? "",
            accountName: file.properties["accountName"] ?? "",
            createdAtMillis: file.createdAtMillis,
            encryptedPayload: response.body,
            schemaVersion: file.schemaVersion
        )
    }

    func deletePasskeyBackup(storageKey: String) async throws {
        let storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        guard let file = try await findBackup(storageKey: storageKey) else { return }
        let response = try await execute(method: "DELETE", url: Self.url(base: Self.baseURL, fileID: file.id))
        if response.statusCode != 404 { try Self.requireSuccess(response) }
    }

    private struct BackupFile {
        let id: String
        let properties: [String: String]
        let createdAtMillis: Int64
        let schemaVersion: Int
    }

    private func findBackup(storageKey: String) async throws -> BackupFile? {
        let storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        let url = try Self.url(base: Self.baseURL, query: [
            "spaces": Self.appDataFolder,
            "pageSize": "2",
            "fields": "nextPageToken,incompleteSearch,files(id,name,appProperties)",
            "q": "name = '\(Self.fileName(storageKey))' and trashed = false"
        ])
        let response = try await execute(method: "GET", url: url)
        try Self.requireSuccess(response)
        guard let root = try JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let files = root["files"] as? [Any] else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        // A partial first page is never proof of absence or uniqueness. Do not create or choose a file.
        guard root["nextPageToken"] == nil,
              root["incompleteSearch"] == nil || (root["incompleteSearch"] as? Bool) == false,
              files.count <= 1 else {
            throw GoogleDrivePasskeyBackupError.ambiguousBackup
        }
        return try files.first.map { try Self.decodeFile($0, storageKey: storageKey) }
    }

    private func execute(
        method: String, url: URL, headers: [String: String] = [:], body: Data? = nil
    ) async throws -> PasskeyBackupHTTPResponse {
        try Task.checkCancellation()
        let authorization = try await tokenProvider.authorization()
        try Task.checkCancellation()
        guard authorization.account.subject == account.subject
        else { throw GoogleDrivePasskeyBackupError.accountChanged }
        try authorization.validate(now: now())
        let request = PasskeyBackupHTTPRequest(
            method: method, url: url,
            headers: headers.merging(["Authorization": "Bearer \(authorization.accessToken)"]) { _, new in new },
            body: body
        )
        // No application retry, including on 401, timeout, cancellation or an ambiguous upload outcome.
        let response = try await transport.execute(request)
        try Task.checkCancellation()
        guard response.body.count <= PasskeyBackupHTTPTransportPolicy.maximumResponseBytes else {
            throw PasskeyBackupError.challengeServiceResponseTooLarge
        }
        return response
    }

    private static func properties(_ record: PasskeyBackupEncryptedRecord) throws -> [String: String] {
        let properties = [
            "storageKey": record.storageKey,
            "walletId": record.walletId,
            "accountName": record.accountName,
            "createdAtMillis": String(record.createdAtMillis),
            "schemaVersion": String(record.schemaVersion)
        ]
        guard properties.allSatisfy({ $0.key.utf8.count + $0.value.utf8.count <= 124 }) else {
            throw GoogleDrivePasskeyBackupError.metadataTooLarge
        }
        return properties
    }

    private static func decodeFile(_ value: Any, storageKey: String) throws -> BackupFile {
        guard let file = value as? [String: Any],
              let id = file["id"] as? String,
              id.range(of: #"\A[A-Za-z0-9_-]{1,256}\z"#, options: .regularExpression) != nil,
              file["name"] as? String == fileName(storageKey),
              let properties = file["appProperties"] as? [String: String],
              Set(properties.keys) ==
              Set(["storageKey", "walletId", "accountName", "createdAtMillis", "schemaVersion"]),
              properties["storageKey"] == storageKey,
              let createdAtText = properties["createdAtMillis"], let createdAt = Int64(createdAtText),
              String(createdAt) == createdAtText,
              let schemaText = properties["schemaVersion"], let schema = Int(schemaText),
              String(schema) == schemaText, schema == PasskeyBackupContract.schemaVersion,
              properties.allSatisfy({ $0.key.utf8.count + $0.value.utf8.count <= 124 }) else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        _ = try PasskeyBackupContract.validateWalletId(properties["walletId"] ?? "")
        _ = try PasskeyBackupContract.validateAccountName(properties["accountName"] ?? "")
        _ = try PasskeyBackupContract.validateCreatedAtMillis(createdAt)
        return BackupFile(id: id, properties: properties, createdAtMillis: createdAt, schemaVersion: schema)
    }

    private static func fileName(_ storageKey: String) -> String { "fearless-passkey-backup-\(storageKey).bin" }

    private static func url(base: String, fileID: String? = nil, query: [String: String] = [:]) throws -> URL {
        var components = URLComponents(string: base)
        if let fileID { components?.path.append("/\(fileID)") }
        components?.queryItems = query.isEmpty ? nil : query.sorted { $0.key < $1.key }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw GoogleDrivePasskeyBackupError.malformedResponse }
        return url
    }

    private static func requireSuccess(_ response: PasskeyBackupHTTPResponse) throws {
        guard (200 ... 299).contains(response.statusCode)
        else { throw GoogleDrivePasskeyBackupError.httpStatus(response.statusCode) }
    }
}

@MainActor
extension PasskeyBackupComposition {
    /// Explicit consent starts only after the compiled release gate opens. No backup screen calls this yet.
    static func requestGoogleDriveAccountConsent(
        presenting: UIViewController,
        accountConfirmer: GoogleDriveBackupAccountConfirming? = nil,
        makeSession: (() throws -> GoogleDriveBackupOAuthSession)? = nil
    ) async throws -> GoogleDrivePasskeyBackupTokenProvider {
        try PasskeyBackupReleaseConfig.validateEnabled()
        try Task.checkCancellation()
        let session = try makeSession?() ?? NativeGoogleDriveBackupOAuthSession()
        return try await GoogleDrivePasskeyBackupTokenProvider.requestConsent(
            presenting: presenting, session: session, accountConfirmer: accountConfirmer
        )
    }

    /// Drive is the portable primary store; callers may explicitly save an optional CloudKit copy separately.
    /// Missing owner authorization/recoverable key implementations still fail closed in the workflow.
    static func makeGoogleDriveClient(
        account: GoogleDriveBackupAccount,
        tokenProvider: GoogleDriveBackupAccessTokenProvider,
        challengeService: PasskeyBackupChallengeService,
        backupKeyProvider: RecoverablePasskeyBackupKeyProvider = UnavailablePasskeyBackupKeyProvider(),
        presentationAnchorProvider: @escaping () -> UIWindow
    ) throws -> PasskeyBackupClient {
        try PasskeyBackupReleaseConfig.validateEnabled()
        let storage = GoogleDrivePasskeyBackupCloudStorage(
            account: account, tokenProvider: tokenProvider, transport: try URLSessionPasskeyBackupHTTPTransport()
        )
        return try makeClient(
            challengeService: challengeService, cloudStorage: storage, backupKeyProvider: backupKeyProvider,
            presentationAnchorProvider: presentationAnchorProvider
        )
    }
}
