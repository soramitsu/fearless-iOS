import Foundation

enum PasskeyBackupAuthenticatedHeadError: Error, Equatable {
    case invalidDescriptor
    case wrongOwner
    case wrongStorageAccount
    case brokenHistory
    case missingHead
}

/// Metadata from an authenticated owner session. Its fields alone do not authenticate an HTTP response.
struct PasskeyBackupHeadDescriptor: CustomStringConvertible, CustomDebugStringConvertible {
    let headRevision: Int64
    let parentHeadRevision: Int64
    let parentHeadSha256: String?
    let generationId: String
    let bundleSha256: String
    let keyEpoch: Int64
    let driveFileID: String
    let storageAccountBinding: String

    init(
        headRevision: Int64, parentHeadRevision: Int64, parentHeadSha256: String?,
        generationId: String, bundleSha256: String, keyEpoch: Int64,
        driveFileID: String, storageAccountBinding: String
    ) throws {
        guard headRevision > 0, headRevision - 1 == parentHeadRevision,
              Self.isDigest(bundleSha256) else {
            throw PasskeyBackupAuthenticatedHeadError.invalidDescriptor
        }
        try GoogleDriveGenerationResponse.requireFileID(driveFileID)
        // Reuse the shared FPBKGEN1 validator for generation, parent, epoch and account identity.
        _ = try PasskeyBackupGenerationV1.Context(
            ownerSubject: Self.placeholderOwner, backupNamespace: Self.placeholderNamespace,
            generationId: generationId, parentHeadRevision: parentHeadRevision,
            parentHeadSha256: parentHeadSha256, keyEpoch: keyEpoch,
            storageAccountBinding: storageAccountBinding
        )
        self.headRevision = headRevision
        self.parentHeadRevision = parentHeadRevision
        self.parentHeadSha256 = parentHeadSha256
        self.generationId = generationId
        self.bundleSha256 = bundleSha256
        self.keyEpoch = keyEpoch
        self.driveFileID = driveFileID
        self.storageAccountBinding = storageAccountBinding
    }

    var description: String { "PasskeyBackupHeadDescriptor(<redacted>)" }
    var debugDescription: String { description }

    func expectedContext(ownerSubject: String, backupNamespace: String) throws
        -> PasskeyBackupGenerationV1.Context {
        try PasskeyBackupGenerationV1.Context(
            ownerSubject: ownerSubject, backupNamespace: backupNamespace,
            generationId: generationId, parentHeadRevision: parentHeadRevision,
            parentHeadSha256: parentHeadSha256, keyEpoch: keyEpoch,
            storageAccountBinding: storageAccountBinding
        )
    }

    private static func isDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48 ... 57).contains($0) || (97 ... 102).contains($0) }
    }

    private static let placeholderOwner = "owner:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
    private static let placeholderNamespace = "backup:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
}

/// The caller must obtain this from a fresh, authenticated owner-session response.
/// A current head is never inferred from Drive listing or an app-private journal.
struct PasskeyBackupAuthenticatedHead: CustomStringConvertible, CustomDebugStringConvertible {
    let ownerSubject: String
    let backupNamespace: String
    let head: PasskeyBackupHeadDescriptor?
    let previous: PasskeyBackupHeadDescriptor?

    init(
        ownerSubject: String, backupNamespace: String,
        head: PasskeyBackupHeadDescriptor?, previous: PasskeyBackupHeadDescriptor?,
        expectedOwnerSubject: String, expectedBackupNamespace: String,
        expectedStorageAccountBinding: String
    ) throws {
        guard ownerSubject == expectedOwnerSubject, backupNamespace == expectedBackupNamespace else {
            throw PasskeyBackupAuthenticatedHeadError.wrongOwner
        }
        // Validate owner and namespace even when no backup head exists yet.
        _ = try PasskeyBackupGenerationV1.Context(
            ownerSubject: ownerSubject, backupNamespace: backupNamespace,
            generationId: "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
            parentHeadRevision: 0, parentHeadSha256: nil, keyEpoch: 1,
            storageAccountBinding: expectedStorageAccountBinding
        )
        guard head?.storageAccountBinding == expectedStorageAccountBinding || head == nil,
              previous?.storageAccountBinding == expectedStorageAccountBinding || previous == nil else {
            throw PasskeyBackupAuthenticatedHeadError.wrongStorageAccount
        }
        switch (head, previous) {
        case (nil, nil):
            break
        case let (head?, nil):
            guard head.headRevision == 1 else { throw PasskeyBackupAuthenticatedHeadError.brokenHistory }
        case let (head?, previous?):
            guard head.headRevision > 1, previous.headRevision == head.parentHeadRevision,
                  head.parentHeadSha256 == previous.bundleSha256,
                  previous.keyEpoch <= head.keyEpoch,
                  previous.generationId != head.generationId,
                  previous.driveFileID != head.driveFileID else {
                throw PasskeyBackupAuthenticatedHeadError.brokenHistory
            }
        case (nil, _?):
            throw PasskeyBackupAuthenticatedHeadError.brokenHistory
        }
        self.ownerSubject = ownerSubject
        self.backupNamespace = backupNamespace
        self.head = head
        self.previous = previous
    }

    var description: String { "PasskeyBackupAuthenticatedHead(<redacted>)" }
    var debugDescription: String { description }

    func currentReadParameters() throws -> (
        fileID: String, context: PasskeyBackupGenerationV1.Context, sha256: String
    ) {
        guard let head else { throw PasskeyBackupAuthenticatedHeadError.missingHead }
        return try (
            head.driveFileID,
            head.expectedContext(ownerSubject: ownerSubject, backupNamespace: backupNamespace),
            head.bundleSha256
        )
    }
}
