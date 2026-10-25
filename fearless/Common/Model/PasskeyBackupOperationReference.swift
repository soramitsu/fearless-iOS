import Foundation

/// An immutable journaled operation can be queried after its expected parent head advances.
/// This reference grants no write authority and contains no wallet plaintext or PRF output.
struct PasskeyBackupOperationReference: CustomStringConvertible, CustomDebugStringConvertible {
    let operationID: String
    let context: PasskeyBackupGenerationV1.Context
    let bundleSHA256: String
    let driveFileID: String

    init(
        operationID: String, context: PasskeyBackupGenerationV1.Context,
        bundleSHA256: String, driveFileID: String
    ) throws {
        guard PasskeyBackupGenerationMetadata.validID(operationID, prefix: ""),
              operationID != context.generationId,
              PasskeyBackupGenerationMetadata.validDigest(bundleSHA256),
              context.parentHeadRevision < 9_007_199_254_740_991 else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
        do {
            try GoogleDriveGenerationResponse.requireFileID(driveFileID)
        } catch {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
        self.operationID = operationID
        self.context = context
        self.bundleSHA256 = bundleSHA256
        self.driveFileID = driveFileID
    }

    init(journalEntry: PasskeyBackupGenerationJournalEntry) throws {
        guard journalEntry.sha256 == PasskeyBackupGenerationV1Format.sha256(journalEntry.bytes) else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
        try self.init(
            operationID: journalEntry.operationID, context: journalEntry.context,
            bundleSHA256: journalEntry.sha256, driveFileID: journalEntry.fileID
        )
    }

    func requireScope(session: PasskeyBackupOwnerSession, storageBinding: String) throws {
        guard context.ownerSubject == session.ownerSubject,
              context.backupNamespace == session.backupNamespace,
              context.storageAccountBinding == storageBinding else {
            throw PasskeyBackupOwnerGenerationHTTPError.invalidMetadata
        }
    }

    func requireDescriptor(_ descriptor: PasskeyBackupHeadDescriptor) throws {
        guard descriptor.headRevision == context.parentHeadRevision + 1,
              descriptor.parentHeadRevision == context.parentHeadRevision,
              descriptor.parentHeadSha256 == context.parentHeadSha256,
              descriptor.generationId == context.generationId,
              descriptor.bundleSha256 == bundleSHA256,
              descriptor.keyEpoch == context.keyEpoch,
              descriptor.driveFileID == driveFileID,
              descriptor.storageAccountBinding == context.storageAccountBinding else {
            throw PasskeyBackupOwnerGenerationHTTPError.malformedResponse
        }
    }

    var description: String {
        "PasskeyBackupOperationReference(<redacted>)"
    }

    var debugDescription: String {
        description
    }
}
