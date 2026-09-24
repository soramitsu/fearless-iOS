import Foundation

enum PasskeyBackupOwnerGenerationHTTPError: Error, Equatable {
    case invalidEndpoint
    case invalidMetadata
    case invalidGrant
    case malformedResponse
    case responseTooLarge
    case httpStatus(Int)
}

/// Public metadata for one immutable Drive generation, anchored to an authenticated owner head.
/// Neither this value nor an owner commit proves that the encrypted bytes can be decrypted.
struct PasskeyBackupGenerationMetadata: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let operationID: String
    let context: PasskeyBackupGenerationV1.Context
    let bundleSHA256: String
    let driveFileID: String
    let expectedHeadRevision: Int64
    let expectedHeadSHA256: String?
    private let requestBody: Data

    init(
        operationID: String, candidate: GoogleDrivePasskeyGenerationStorage.Candidate,
        authenticatedHead: PasskeyBackupAuthenticatedHead
    ) throws {
        let context = candidate.context
        let revision = authenticatedHead.head?.headRevision ?? 0
        let parentDigest = authenticatedHead.head?.bundleSha256
        guard Self.validID(operationID, prefix: ""), operationID != context.generationId,
              Self.validDigest(candidate.sha256),
              context.ownerSubject == authenticatedHead.ownerSubject,
              context.backupNamespace == authenticatedHead.backupNamespace,
              context.parentHeadRevision == revision, context.parentHeadSha256 == parentDigest,
              authenticatedHead.head?.storageAccountBinding == context.storageAccountBinding ||
              authenticatedHead.head == nil,
              authenticatedHead.previous?.storageAccountBinding == context.storageAccountBinding ||
              authenticatedHead.previous == nil,
              revision < Self.maximumSafeInteger, context.keyEpoch <= Self.maximumSafeInteger else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
        do {
            try GoogleDriveGenerationResponse.requireFileID(candidate.fileID)
        } catch {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
        let body: [String: Any] = [
            "schemaVersion": 1, "operationId": operationID,
            "generationId": context.generationId, "backupNamespace": context.backupNamespace,
            "expectedHeadRevision": String(revision),
            "expectedHeadSha256": parentDigest.map { $0 as Any } ?? NSNull(),
            "bundleSha256": candidate.sha256, "keyEpoch": String(context.keyEpoch),
            "driveFileId": candidate.fileID, "storageAccountBinding": context.storageAccountBinding
        ]
        guard let encoded = try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys]) else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
        self.operationID = operationID
        self.context = context
        bundleSHA256 = candidate.sha256
        driveFileID = candidate.fileID
        expectedHeadRevision = revision
        expectedHeadSHA256 = parentDigest
        requestBody = encoded
    }

    fileprivate var body: Data {
        requestBody
    }

    fileprivate var digest: String {
        PasskeyBackupGenerationV1Format.sha256(requestBody)
    }

    fileprivate func requireScope(session: PasskeyBackupOwnerSession, storageBinding: String) throws {
        guard context.ownerSubject == session.ownerSubject,
              context.backupNamespace == session.backupNamespace,
              context.storageAccountBinding == storageBinding else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
    }

    fileprivate func requireDescriptor(_ descriptor: PasskeyBackupHeadDescriptor) throws {
        guard descriptor.headRevision == expectedHeadRevision + 1,
              descriptor.parentHeadRevision == expectedHeadRevision,
              descriptor.parentHeadSha256 == expectedHeadSHA256,
              descriptor.generationId == context.generationId,
              descriptor.bundleSha256 == bundleSHA256,
              descriptor.keyEpoch == context.keyEpoch,
              descriptor.driveFileID == driveFileID,
              descriptor.storageAccountBinding == context.storageAccountBinding else {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
    }

    private static let maximumSafeInteger: Int64 = 9_007_199_254_740_991

    fileprivate static func validID(_ value: String, prefix: String) -> Bool {
        guard value.hasPrefix(prefix) else { return false }
        let token = String(value.dropFirst(prefix.count))
        return token.utf8.count == 43 && (try? PasskeyBackupContract.decodeBase64URL(token))?.count == 32
    }

    private static func validDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48 ... 57).contains($0) || (97 ... 102).contains($0) }
    }

    var description: String {
        "PasskeyBackupGenerationMetadata(<redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(self, children: [])
    }
}

/// One-use owner grant, bound locally to the original owner session and exact metadata body.
struct PasskeyBackupGenerationGrant: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    let token: String
    let expiresAtUnixSeconds: Int64
    private let sessionToken: String
    private let metadataDigest: String

    fileprivate init(
        token: String,
        expiresAtUnixSeconds: Int64,
        session: PasskeyBackupOwnerSession,
        metadata: PasskeyBackupGenerationMetadata
    ) {
        self.token = token
        self.expiresAtUnixSeconds = expiresAtUnixSeconds
        sessionToken = session.token
        metadataDigest = metadata.digest
    }

    fileprivate func requireFor(
        session: PasskeyBackupOwnerSession, metadata: PasskeyBackupGenerationMetadata, now: Int64
    ) throws {
        guard PasskeyBackupGenerationMetadata.validID(token, prefix: "grant."),
              session.token == sessionToken,
              metadata.digest == metadataDigest, expiresAtUnixSeconds > now else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidGrant
        }
    }

    var description: String {
        "PasskeyBackupGenerationGrant(<redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(self, children: [])
    }
}

enum PasskeyBackupGenerationOperationStatus: Equatable, CustomStringConvertible {
    case absent
    case committed(PasskeyBackupHeadDescriptor)

    var description: String {
        switch self {
        case .absent: return "PasskeyBackupGenerationOperationStatus.absent"
        case .committed: return "PasskeyBackupGenerationOperationStatus.committed(<redacted>)"
        }
    }
}

/// Disabled metadata-only candidate. Callers must prove upload, readback, decryption and original
/// key signing/export independently before commit; no production caller or completion flag exists.
final class HTTPPasskeyBackupOwnerGenerationClient {
    private static let grantPath = "/api/passkey-backup/v1/owner/backup/grant"
    private static let commitPath = "/api/passkey-backup/v1/owner/backup/commit"
    private static let operationPath = "/api/passkey-backup/v1/owner/backup/operation"
    private static let maximumResponseBytes = 8192

    private let baseURL: URL
    private let transport: PasskeyBackupHTTPTransport
    private let tokenProvider: GoogleDriveBackupAccessTokenProvider
    private let nowUnixSeconds: () -> Int64
    private let isReleaseEnabled: Bool

    init(
        baseURL: URL, transport: PasskeyBackupHTTPTransport,
        tokenProvider: GoogleDriveBackupAccessTokenProvider,
        nowUnixSeconds: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) },
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled
    ) throws {
        guard let components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false),
              components.scheme == "https", let host = components.host, !host.isEmpty,
              host == host.lowercased(), components.user == nil, components.password == nil,
              components.port == nil, components.query == nil, components.fragment == nil,
              components.percentEncodedPath.isEmpty || components.percentEncodedPath == "/",
              baseURL.absoluteString == "https://\(host)" || baseURL.absoluteString == "https://\(host)/" else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidEndpoint
        }
        self.baseURL = URL(string: "https://\(host)")!
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.nowUnixSeconds = nowUnixSeconds
        self.isReleaseEnabled = isReleaseEnabled
    }

    @available(iOS 15.0, macOS 12.0, *)
    convenience init(
        baseURL: URL = PasskeyBackupReleaseConfig.challengeServiceBaseURL,
        tokenProvider: GoogleDriveBackupAccessTokenProvider
    ) throws {
        try self.init(
            baseURL: baseURL,
            transport: URLSessionPasskeyBackupHTTPTransport(maximumResponseBytes: Self.maximumResponseBytes),
            tokenProvider: tokenProvider
        )
    }

    func grant(
        session: PasskeyBackupOwnerSession, metadata: PasskeyBackupGenerationMetadata
    ) async throws -> PasskeyBackupGenerationGrant {
        let response = try await execute(
            path: Self.grantPath, bearer: session.token, session: session,
            metadata: metadata, body: metadata.body
        )
        let grant = try Self.decodeGrant(response.body, session: session, metadata: metadata, now: nowUnixSeconds())
        try Task.checkCancellation()
        try session.requireFresh(nowUnixSeconds: nowUnixSeconds())
        try grant.requireFor(session: session, metadata: metadata, now: nowUnixSeconds())
        return grant
    }

    /// A successful metadata CAS is not proof of a usable backup.
    func commit(
        session: PasskeyBackupOwnerSession, metadata: PasskeyBackupGenerationMetadata,
        grant: PasskeyBackupGenerationGrant
    ) async throws -> PasskeyBackupHeadDescriptor {
        try grant.requireFor(session: session, metadata: metadata, now: nowUnixSeconds())
        let response = try await execute(
            path: Self.commitPath, bearer: grant.token, session: session,
            metadata: metadata, body: metadata.body,
            extraHeaders: ["X-Passkey-Owner-Session": session.token]
        )
        try grant.requireFor(session: session, metadata: metadata, now: nowUnixSeconds())
        guard case let .committed(descriptor) = try Self.decodeStatus(
            response.body, metadata: metadata, allowAbsent: false
        ) else { throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse }
        return descriptor
    }

    /// After an unknown commit outcome, absence requires reconciliation, not another upload.
    func operationStatus(
        session: PasskeyBackupOwnerSession, metadata: PasskeyBackupGenerationMetadata
    ) async throws -> PasskeyBackupGenerationOperationStatus {
        let body = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "operationId": metadata.operationID
        ], options: [.sortedKeys])
        let response = try await execute(
            path: Self.operationPath, bearer: session.token, session: session,
            metadata: metadata, body: body
        )
        return try Self.decodeStatus(response.body, metadata: metadata, allowAbsent: true)
    }

    private func execute(
        path: String, bearer: String, session: PasskeyBackupOwnerSession,
        metadata: PasskeyBackupGenerationMetadata, body: Data,
        extraHeaders: [String: String] = [:]
    ) async throws -> PasskeyBackupHTTPResponse {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try Task.checkCancellation()
        try session.requireFresh(nowUnixSeconds: nowUnixSeconds())
        let bearerPrefix = path == Self.commitPath ? "grant." : "session."
        guard PasskeyBackupGenerationMetadata.validID(bearer, prefix: bearerPrefix) else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidGrant
        }
        let selected = try await tokenProvider.authorization()
        try selected.validate(now: Date(timeIntervalSince1970: TimeInterval(nowUnixSeconds())))
        let selectedSubject = selected.account.subject
        let binding = try PasskeyBackupGenerationV1Format.storageAccountBinding(verifiedGoogleSubject: selectedSubject)
        try Task.checkCancellation()
        try session.requireFresh(nowUnixSeconds: nowUnixSeconds())
        try metadata.requireScope(session: session, storageBinding: binding)
        let response = try await transport.execute(PasskeyBackupHTTPRequest(
            method: "POST", url: baseURL.appendingPathComponent(String(path.dropFirst())),
            headers: [
                "Authorization": "Bearer \(bearer)",
                "Content-Type": "application/json; charset=utf-8",
                "Cache-Control": "no-store"
            ].merging(extraHeaders) { _, added in added }, body: body
        ))
        try Task.checkCancellation()
        try session.requireFresh(nowUnixSeconds: nowUnixSeconds())
        let current = try await tokenProvider.authorization()
        try current.validate(now: Date(timeIntervalSince1970: TimeInterval(nowUnixSeconds())))
        guard current.account.subject == selectedSubject else {
            throw GoogleDrivePasskeyBackupError.accountChanged
        }
        try Task.checkCancellation()
        try session.requireFresh(nowUnixSeconds: nowUnixSeconds())
        guard response.body.count <= Self.maximumResponseBytes else {
            throw PasskeyBackupOwnerGenerationHTTPError.responseTooLarge
        }
        guard response.statusCode == 200 else {
            throw PasskeyBackupOwnerGenerationHTTPError.httpStatus(response.statusCode)
        }
        return response
    }

    private static func decodeGrant(
        _ data: Data, session: PasskeyBackupOwnerSession,
        metadata: PasskeyBackupGenerationMetadata, now: Int64
    ) throws -> PasskeyBackupGenerationGrant {
        let object = try parse(data)
        guard Set(object.keys) == Set(["token", "expiresAt"]),
              case let .string(token) = object["token"],
              case let .number(expiry) = object["expiresAt"],
              PasskeyBackupGenerationMetadata.validID(token, prefix: "grant."),
              now >= 0, now <= Int64.max - 65,
              expiry > now, expiry <= now + 65,
              expiry <= session.expiresAtUnixSeconds else {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
        return PasskeyBackupGenerationGrant(
            token: token, expiresAtUnixSeconds: expiry, session: session, metadata: metadata
        )
    }

    private static func decodeStatus(
        _ data: Data, metadata: PasskeyBackupGenerationMetadata, allowAbsent: Bool
    ) throws -> PasskeyBackupGenerationOperationStatus {
        let object = try parse(data)
        if object["status"] == .string("absent") {
            guard allowAbsent, Set(object.keys) == Set(["status"]) else {
                throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
            }
            return .absent
        }
        guard object["status"] == .string("committed"),
              Set(object.keys) == Set(["status", "descriptor"]),
              case let .object(fields) = object["descriptor"],
              Set(fields.keys) == Set([
                  "headRevision", "parentHeadRevision", "parentHeadSha256", "generationId",
                  "bundleSha256", "keyEpoch", "driveFileId", "storageAccountBinding"
              ]),
              case let .string(revision) = fields["headRevision"],
              case let .string(parentRevision) = fields["parentHeadRevision"],
              case let .string(generationID) = fields["generationId"],
              case let .string(bundleDigest) = fields["bundleSha256"],
              case let .string(epoch) = fields["keyEpoch"],
              case let .string(fileID) = fields["driveFileId"],
              case let .string(binding) = fields["storageAccountBinding"] else {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
        let parentDigest: String?
        switch fields["parentHeadSha256"] {
        case .null: parentDigest = nil
        case let .string(value): parentDigest = value
        default: throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
        do {
            let descriptor = try PasskeyBackupHeadDescriptor(
                headRevision: decimal(revision), parentHeadRevision: decimal(parentRevision),
                parentHeadSha256: parentDigest, generationId: generationID,
                bundleSha256: bundleDigest, keyEpoch: decimal(epoch),
                driveFileID: fileID, storageAccountBinding: binding
            )
            try metadata.requireDescriptor(descriptor)
            return .committed(descriptor)
        } catch {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
    }

    private static func parse(_ data: Data) throws -> [String: PasskeyBackupOwnerResponseJSON.Value] {
        guard (1 ... maximumResponseBytes).contains(data.count) else {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
        do {
            return try PasskeyBackupOwnerResponseJSON.parseObject(data)
        } catch {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
    }

    private static func decimal(_ text: String) throws -> Int64 {
        guard let value = Int64(text), value >= 0, value <= 9_007_199_254_740_991,
              String(value) == text else {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
        return value
    }
}
