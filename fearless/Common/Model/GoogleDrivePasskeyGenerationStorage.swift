import Foundation

/// Append-only ciphertext storage. This primitive cannot change an owner head, overwrite, delete or decrypt.
final class GoogleDrivePasskeyGenerationStorage {
    struct Candidate: CustomStringConvertible, CustomDebugStringConvertible {
        let fileID: String
        let context: PasskeyBackupGenerationV1.Context
        let bytes: Data
        let sha256: String
        var size: Int { bytes.count }

        fileprivate init(fileID: String, generation: PasskeyBackupGenerationV1) throws {
            try GoogleDriveGenerationResponse.requireFileID(fileID)
            self.fileID = fileID
            context = generation.context
            bytes = try PasskeyBackupGenerationV1Format.encode(generation)
            sha256 = PasskeyBackupGenerationV1Format.sha256(bytes)
        }

        var description: String { "DriveGenerationCandidate(<redacted>)" }
        var debugDescription: String { description }
    }

    enum CreateOutcome { case acknowledged, reconcileRequired }

    private static let baseURL = "https://www.googleapis.com/drive/v3/files"
    private static let uploadURL = "https://www.googleapis.com/upload/drive/v3/files"
    private static let fields = "id,name,mimeType,spaces,appProperties,size"
    private static let mimeType = "application/octet-stream"
    private static let metadataBytes = 8192
    private let account: GoogleDriveBackupAccount
    private let accountBinding: String
    private let tokenProvider: GoogleDriveBackupAccessTokenProvider
    private let transport: PasskeyBackupHTTPTransport
    private let now: () -> Date

    init(
        account: GoogleDriveBackupAccount, tokenProvider: GoogleDriveBackupAccessTokenProvider,
        transport: PasskeyBackupHTTPTransport = URLSessionPasskeyGenerationTransport(),
        now: @escaping () -> Date = Date.init
    ) throws {
        self.account = account
        accountBinding = try PasskeyBackupGenerationV1Format.storageAccountBinding(
            verifiedGoogleSubject: account.subject
        )
        self.tokenProvider = tokenProvider
        self.transport = transport
        self.now = now
    }

    /// Allocating an ID creates no ciphertext. Persist the returned ID before any create request.
    func allocateFileID() async throws -> String {
        let response = try await execute(method: "GET", url: Self.url(
            base: Self.baseURL + "/generateIds", query: ["count": "1", "space": "appDataFolder", "type": "files"]
        ), maximum: Self.metadataBytes)
        guard response.statusCode == 200 else { throw GoogleDrivePasskeyBackupError.httpStatus(response.statusCode) }
        return try GoogleDriveGenerationResponse.allocatedID(response.body)
    }

    /// Persist the exact candidate and owner operation ID in a durable journal before createCandidate.
    func prepareCandidate(fileID: String, generation: PasskeyBackupGenerationV1) throws -> Candidate {
        try requireAccount(generation.context)
        return try Candidate(fileID: fileID, generation: generation)
    }

    /// A durable candidate and attempt marker are required before the only possible POST.
    /// Acknowledgement is not decryption proof or a head commit. An existing marker or
    /// unknown transport outcome requires reconciliation of the same preallocated ID.
    func createCandidate(
        _ candidate: Candidate, operationID: String, journal: PasskeyBackupGenerationJournal,
        expectedScope: PasskeyBackupGenerationJournalScope
    ) async throws -> CreateOutcome {
        try requireAccount(candidate.context)
        _ = try journal.persistPrepared(
            operationID: operationID, candidate: candidate, expectedScope: expectedScope
        )
        let metadata: [String: Any] = [
            "id": candidate.fileID, "name": Self.fileName(candidate.context), "mimeType": Self.mimeType,
            "parents": ["appDataFolder"], "appProperties": Self.properties(candidate.context, digest: candidate.sha256)
        ]
        let boundary = "fearless-generation-\(UUID().uuidString)"
        var body = Data("--\(boundary)\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n".utf8)
        try body.append(JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys]))
        body.append(Data("\r\n--\(boundary)\r\nContent-Type: \(Self.mimeType)\r\n\r\n".utf8))
        body.append(candidate.bytes)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let request = try await authorize(
            method: "POST",
            url: Self.url(base: Self.uploadURL, query: ["uploadType": "multipart", "fields": Self.fields]),
            headers: ["Content-Type": "multipart/related; boundary=\(boundary)"], body: body
        )
        try Task.checkCancellation()
        guard try journal.admitFirstCreateAttempt(
            operationID: operationID, expectedScope: expectedScope
        ) else { return .reconcileRequired }
        let response: PasskeyBackupHTTPResponse
        do {
            response = try await transport.execute(request)
        } catch {
            try Task.checkCancellation()
            if error is CancellationError { throw error }
            return .reconcileRequired
        }
        try Task.checkCancellation()
        guard response.statusCode == 200 || response.statusCode == 201,
              let size = try? Self.metadataSize(
                  response.body,
                  fileID: candidate.fileID,
                  context: candidate.context,
                  digest: candidate.sha256
              ),
              size == candidate.size else { return .reconcileRequired }
        return .acknowledged
    }

    /// Expected context/digest must come from authenticated owner state or a durable local journal.
    /// nil observes a 404 only; it never permits abandoning, recreating or deleting a candidate.
    func readCandidate(
        fileID: String, expectedContext: PasskeyBackupGenerationV1.Context, expectedSha256: String
    ) async throws -> PasskeyBackupGenerationV1? {
        try GoogleDriveGenerationResponse.requireFileID(fileID)
        guard expectedSha256.range(of: #"\A[0-9a-f]{64}\z"#, options: .regularExpression) != nil else {
            throw PasskeyBackupGenerationError.invalidContext
        }
        try requireAccount(expectedContext)
        let metadata = try await execute(method: "GET", url: Self.url(
            base: Self.baseURL + "/" + fileID, query: ["fields": Self.fields]
        ), maximum: Self.metadataBytes)
        if metadata.statusCode == 404 { return nil }
        guard metadata.statusCode == 200 else { throw GoogleDrivePasskeyBackupError.httpStatus(metadata.statusCode) }
        let size = try Self.metadataSize(
            metadata.body, fileID: fileID, context: expectedContext, digest: expectedSha256
        )
        let response = try await execute(method: "GET", url: Self.url(
            base: Self.baseURL + "/" + fileID, query: ["alt": "media"]
        ), maximum: size)
        if response.statusCode == 404 { return nil }
        guard response.statusCode == 200, response.body.count == size else {
            throw GoogleDrivePasskeyBackupError.malformedResponse
        }
        return try PasskeyBackupGenerationV1Format.decode(
            response.body, expectedContext: expectedContext, expectedSha256: expectedSha256
        )
    }

    /// Restore reads the exact committed owner head, never a Drive listing or a local hint.
    /// The caller must obtain `authenticatedHead` from a fresh owner session and still unwrap,
    /// decrypt, and verify the original wallet before reporting recovery.
    func readCurrentHead(_ authenticatedHead: PasskeyBackupAuthenticatedHead) async throws
        -> PasskeyBackupGenerationV1? {
        let expected = try authenticatedHead.currentReadParameters()
        return try await readCandidate(
            fileID: expected.fileID, expectedContext: expected.context,
            expectedSha256: expected.sha256
        )
    }

    /// Recheck the selected Google identity after an asynchronous local wallet ceremony.
    /// This does not read or mutate a Drive file.
    func requireSelectedAccount() async throws {
        try Task.checkCancellation()
        let authorization = try await tokenProvider.authorization()
        try Task.checkCancellation()
        guard authorization.account.subject == account.subject else {
            throw GoogleDrivePasskeyBackupError.accountChanged
        }
        try authorization.validate(now: now())
    }

    private func requireAccount(_ context: PasskeyBackupGenerationV1.Context) throws {
        guard context.storageAccountBinding == accountBinding else {
            throw GoogleDrivePasskeyBackupError.accountChanged
        }
    }

    private func authorize(
        method: String, url: URL, headers: [String: String] = [:], body: Data? = nil
    ) async throws -> PasskeyBackupHTTPRequest {
        try Task.checkCancellation()
        let authorization = try await tokenProvider.authorization()
        try Task.checkCancellation()
        guard authorization.account.subject == account.subject else {
            throw GoogleDrivePasskeyBackupError.accountChanged
        }
        try authorization.validate(now: now())
        return PasskeyBackupHTTPRequest(method: method, url: url, headers: headers.merging([
            "Authorization": "Bearer \(authorization.accessToken)", "Cache-Control": "no-store"
        ]) { _, new in new }, body: body)
    }

    private func execute(method: String, url: URL, maximum: Int) async throws -> PasskeyBackupHTTPResponse {
        let request = try await authorize(method: method, url: url)
        let response = try await transport.execute(request)
        try Task.checkCancellation()
        guard response.body.count <= maximum else { throw PasskeyBackupError.challengeServiceResponseTooLarge }
        return response
    }

    private static func metadataSize(
        _ data: Data, fileID: String, context: PasskeyBackupGenerationV1.Context, digest: String
    ) throws -> Int {
        try GoogleDriveGenerationResponse.metadataSize(
            data, fileID: fileID, name: fileName(context), properties: properties(context, digest: digest)
        )
    }

    private static func fileName(_ context: PasskeyBackupGenerationV1.Context) -> String {
        "fearless-passkey-generation-\(context.generationId).bin"
    }

    private static func properties(_ context: PasskeyBackupGenerationV1.Context, digest: String) -> [String: String] {
        ["format": "FPBKGEN1", "generationId": context.generationId, "bundleSha256": digest,
         "namespaceSha256": PasskeyBackupGenerationV1Format.sha256(Data(context.backupNamespace.utf8))]
    }

    private static func url(base: String, query: [String: String]) throws -> URL {
        var components = URLComponents(string: base)
        components?.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else { throw GoogleDrivePasskeyBackupError.malformedResponse }
        return url
    }
}
