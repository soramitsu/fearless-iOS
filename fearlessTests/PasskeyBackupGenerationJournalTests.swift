@testable import fearless
import Foundation
import XCTest

final class PasskeyBackupGenerationJournalTests: XCTestCase {
    private let operationID = "REREREREREREREREREREREREREREREREREREREREREQ"
    private let fileID = "preallocated-drive-id"
    private let subject = "google-subject-123"

    func testApplicationSupportFactoryCreatesPrivateNoBackupDirectory() throws {
        let journal = try PasskeyBackupGenerationJournal.applicationSupport()
        let parent = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )
        let directory = parent.appendingPathComponent("passkey-generations-v1", isDirectory: true)
        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(values.isExcludedFromBackup, true)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: directory.path)[.posixPermissions] as? Int, 0o700)
        XCTAssertEqual(try journal.listPending(expectedScope: .init(
            ownerSubject: "owner:ERERERERERERERERERERERERERERERERERERERERERE",
            backupNamespace: "backup:iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIg",
            storageAccountBinding: String(repeating: "a", count: 64)
        )).count, 0)
    }

    func testParentDirectorySyncFailureCannotReturnAUsableJournal() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        var parentSyncCalls = 0
        XCTAssertThrowsError(try PasskeyBackupGenerationJournal(
            parentDirectoryURL: parent,
            parentSync: { _ in parentSyncCalls += 1; return -1 }
        ))
        XCTAssertEqual(parentSyncCalls, 1)
        let recovered = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        let (_, scope) = try fixture()
        XCTAssertEqual(try recovered.listPending(expectedScope: scope).count, 0)
    }

    func testCompleteLookingUnsyncedRecordCannotAdmitUntilFileSyncSucceeds() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let (candidate, scope) = try fixture()
        let interrupted = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent) { boundary in
            if case .afterWrite = boundary { throw PasskeyBackupGenerationJournalError.unavailable }
        }
        XCTAssertThrowsError(try interrupted.persistPrepared(
            operationID: operationID, candidate: candidate, expectedScope: scope
        ))
        let recordURL = parent.appendingPathComponent("passkey-generations-v1/op-\(operationID).journal")
        XCTAssertGreaterThan(try Data(contentsOf: recordURL).count, 0)

        let failedSync = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent, fileSync: { _ in -1 })
        XCTAssertThrowsError(try failedSync.persistPrepared(
            operationID: operationID, candidate: candidate, expectedScope: scope
        ))
        XCTAssertThrowsError(try failedSync.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: parent.appendingPathComponent("passkey-generations-v1/op-\(operationID).attempt").path
        ))

        let recovered = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        _ = try recovered.persistPrepared(operationID: operationID, candidate: candidate, expectedScope: scope)
        XCTAssertTrue(try recovered.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
    }

    func testPreparedBytesSurviveRestartAndOnlyOneDurableCreateAttemptIsAdmitted() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let (candidate, scope) = try fixture()
        let first = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        let prepared = try first.persistPrepared(operationID: operationID, candidate: candidate, expectedScope: scope)
        XCTAssertFalse(prepared.createAttempted)
        XCTAssertEqual(prepared.sha256, candidate.sha256)
        XCTAssertEqual(prepared.bytes, candidate.bytes)
        XCTAssertEqual(candidate.bytes.count, 785)
        XCTAssertEqual(candidate.sha256, "1c92b544dc25c687c202317d0e5747b5690a1056cf72e61d1dfab84c07c057a4")
        let recordURL = parent.appendingPathComponent("passkey-generations-v1/op-\(operationID).journal")
        let persistedBytes = try Data(contentsOf: recordURL)
        XCTAssertNil(persistedBytes.range(of: Data("cross-platform-passkey-backup".utf8)))
        XCTAssertNil(persistedBytes.range(of: Data(repeating: 0x66, count: 32)))
        XCTAssertEqual(try first.listPending(expectedScope: scope).count, 1)

        let restarted = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        XCTAssertEqual(try restarted.read(operationID: operationID, expectedScope: scope)?.bytes, candidate.bytes)
        XCTAssertTrue(try restarted.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
        XCTAssertFalse(try first.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
        let pending = try XCTUnwrap(first.read(operationID: operationID, expectedScope: scope))
        XCTAssertTrue(pending.createAttempted)
        XCTAssertEqual(pending.context, candidate.context)
        XCTAssertEqual(try first.persistPrepared(
            operationID: operationID, candidate: candidate, expectedScope: scope
        ).bytes, candidate.bytes)
        XCTAssertTrue(try restarted.read(operationID: operationID, expectedScope: scope)?.createAttempted == true)
        XCTAssertEqual(String(reflecting: pending), "PasskeyBackupGenerationJournalEntry(<redacted>)")
    }

    func testWrongOwnerAccountAndOperationNeverMakeAnotherCandidateUsable() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let (candidate, scope) = try fixture()
        let journal = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        XCTAssertThrowsError(try journal.persistPrepared(
            operationID: "../wrong", candidate: candidate, expectedScope: scope
        ))
        let wrongOwner = PasskeyBackupGenerationJournalScope(
            ownerSubject: "owner:ERERERERERERERERERERERERERERERERERERERERERE",
            backupNamespace: "backup:ERERERERERERERERERERERERERERERERERERERERERE",
            storageAccountBinding: scope.storageAccountBinding
        )
        XCTAssertThrowsError(try journal.persistPrepared(
            operationID: operationID, candidate: candidate, expectedScope: wrongOwner
        ))
        _ = try journal.persistPrepared(operationID: operationID, candidate: candidate, expectedScope: scope)
        let wrongAccount = PasskeyBackupGenerationJournalScope(
            ownerSubject: scope.ownerSubject, backupNamespace: scope.backupNamespace,
            storageAccountBinding: String(repeating: "a", count: 64)
        )
        XCTAssertThrowsError(try journal.read(operationID: operationID, expectedScope: wrongAccount))
        XCTAssertThrowsError(try journal.admitFirstCreateAttempt(operationID: operationID, expectedScope: wrongAccount))
        XCTAssertEqual(try journal.listPending(expectedScope: wrongAccount).count, 0)
        XCTAssertNil(try journal.read(
            operationID: "SEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEg", expectedScope: scope
        ))
    }

    func testCorruptAndPartialRecordsRemainInPlaceAndCannotBeReplaced() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let (candidate, scope) = try fixture()
        let journal = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        _ = try journal.persistPrepared(operationID: operationID, candidate: candidate, expectedScope: scope)
        let recordURL = parent.appendingPathComponent("passkey-generations-v1/op-\(operationID).journal")
        let original = try Data(contentsOf: recordURL)
        var corrupt = original
        corrupt[corrupt.count - 33] ^= 1
        let handle = try FileHandle(forWritingTo: recordURL)
        try handle.write(contentsOf: corrupt)
        try handle.synchronize()
        try handle.close()
        XCTAssertThrowsError(try journal.read(operationID: operationID, expectedScope: scope))
        XCTAssertThrowsError(try journal.persistPrepared(
            operationID: operationID, candidate: candidate, expectedScope: scope
        ))
        XCTAssertEqual(try Data(contentsOf: recordURL), corrupt)

        let secondParent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: secondParent) }
        let second = try PasskeyBackupGenerationJournal(parentDirectoryURL: secondParent)
        let partialURL = secondParent.appendingPathComponent("passkey-generations-v1/op-\(operationID).journal")
        XCTAssertTrue(FileManager.default.createFile(
            atPath: partialURL.path, contents: Data([0x46]), attributes: [.posixPermissions: 0o600]
        ))
        XCTAssertThrowsError(try second.read(operationID: operationID, expectedScope: scope))
        XCTAssertThrowsError(try second.persistPrepared(
            operationID: operationID, candidate: candidate, expectedScope: scope
        ))
        XCTAssertEqual(try Data(contentsOf: partialURL), Data([0x46]))
    }

    func testAnotherOperationCannotReuseDriveIDOrGenerationToBypassAttemptMarker() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let (candidate, scope) = try fixture()
        let journal = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        _ = try journal.persistPrepared(operationID: operationID, candidate: candidate, expectedScope: scope)
        XCTAssertTrue(try journal.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
        let otherOperation = "SEhISEhISEhISEhISEhISEhISEhISEhISEhISEhISEg"
        XCTAssertThrowsError(try journal.persistPrepared(
            operationID: otherOperation, candidate: candidate, expectedScope: scope
        ))
        let account = try GoogleDriveBackupAccount(subject: subject, email: "alice@example.com")
        let store = try GoogleDrivePasskeyGenerationStorage(
            account: account, tokenProvider: NeverJournalTokenProvider()
        )
        let generation = try PasskeyBackupGenerationV1Format.decode(
            candidate.bytes, expectedContext: candidate.context, expectedSha256: candidate.sha256
        )
        let sameGeneration = try store.prepareCandidate(fileID: "different-drive-id", generation: generation)
        XCTAssertThrowsError(try journal.persistPrepared(
            operationID: otherOperation, candidate: sameGeneration, expectedScope: scope
        ))
        XCTAssertFalse(try journal.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
        XCTAssertEqual(try journal.listPending(expectedScope: scope).count, 1)
    }

    func testInterruptedAttemptMarkerRequiresReconciliationAfterRestart() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let (candidate, scope) = try fixture()
        var writes = 0
        let journal = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent) { boundary in
            if case .afterWrite = boundary {
                writes += 1
                if writes == 2 { throw PasskeyBackupGenerationJournalError.unavailable }
            }
        }
        _ = try journal.persistPrepared(operationID: operationID, candidate: candidate, expectedScope: scope)
        XCTAssertThrowsError(try journal.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
        let restarted = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        XCTAssertTrue(try restarted.read(operationID: operationID, expectedScope: scope)?.createAttempted == true)
        XCTAssertFalse(try restarted.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
    }

    func testCommitMarkerIsOneWayAcrossRestartAndPartialWrite() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let (candidate, scope) = try fixture()
        let journal = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        _ = try journal.persistPrepared(operationID: operationID, candidate: candidate, expectedScope: scope)
        XCTAssertTrue(try journal.admitFirstCreateAttempt(operationID: operationID, expectedScope: scope))
        XCTAssertTrue(try journal.admitFirstCommitAttempt(operationID: operationID, expectedScope: scope))
        XCTAssertFalse(try journal.admitFirstCommitAttempt(operationID: operationID, expectedScope: scope))

        let restarted = try PasskeyBackupGenerationJournal(parentDirectoryURL: parent)
        XCTAssertTrue(try XCTUnwrap(restarted.read(
            operationID: operationID, expectedScope: scope
        )).commitAttempted)
        let markerURL = parent.appendingPathComponent("passkey-generations-v1/op-\(operationID).commit")
        let handle = try FileHandle(forWritingTo: markerURL)
        try handle.truncate(atOffset: 3)
        try handle.synchronize()
        try handle.close()
        XCTAssertTrue(try XCTUnwrap(restarted.read(
            operationID: operationID, expectedScope: scope
        )).commitAttempted)
        XCTAssertFalse(try restarted.admitFirstCommitAttempt(operationID: operationID, expectedScope: scope))
        XCTAssertEqual(try restarted.listPending(expectedScope: scope).count, 1)
    }

    func testSymlinkDirectoryIsRejectedBeforeReadingCandidate() throws {
        let parent = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: parent) }
        let elsewhere = try temporaryParent()
        defer { try? FileManager.default.removeItem(at: elsewhere) }
        try FileManager.default.createSymbolicLink(
            at: parent.appendingPathComponent("passkey-generations-v1"), withDestinationURL: elsewhere
        )
        XCTAssertThrowsError(try PasskeyBackupGenerationJournal(parentDirectoryURL: parent))
    }

    private func temporaryParent() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700]
        )
        return url
    }

    private func fixture() throws -> (
        GoogleDrivePasskeyGenerationStorage.Candidate, PasskeyBackupGenerationJournalScope
    ) {
        let account = try GoogleDriveBackupAccount(subject: subject, email: "alice@example.com")
        let store = try GoogleDrivePasskeyGenerationStorage(
            account: account, tokenProvider: NeverJournalTokenProvider()
        )
        let owner = "owner:ERERERERERERERERERERERERERERERERERERERERERE"
        let metadata = try PasskeyBackupEnvelopeMetadata(
            storageKey: "wallet-1234", walletId: "wallet-001",
            accountName: "alice@example.com", createdAtMillis: 1_767_225_600_000
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
                ownerSubject: owner, credentialId: "IiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiI",
                keyEpoch: 7, envelopeMetadata: metadata
            ),
            prfSalt: Data(repeating: 0x33, count: 32),
            hkdfSalt: Data(repeating: 0x44, count: 32), nonce: Data(repeating: 0x55, count: 12),
            ciphertextAndTag: PasskeyBackupContract.decodeBase64URL(
                "m_xnd6ezMk5VjmGJjqjAVrBDJYQTp7NxcktIT8CmyM8uzo4ZphIMYP-2QRflGgs5"
            )
        )
        let context = try PasskeyBackupGenerationV1.Context(
            ownerSubject: owner, backupNamespace: "backup:iIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIg",
            generationId: "mZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZmZk",
            parentHeadRevision: 6, parentHeadSha256: String(repeating: "a", count: 64), keyEpoch: 7,
            storageAccountBinding: PasskeyBackupGenerationV1Format.storageAccountBinding(verifiedGoogleSubject: subject)
        )
        let generation = try PasskeyBackupGenerationV1(context: context, envelope: envelope, wrappers: [wrapper])
        return try (store.prepareCandidate(fileID: fileID, generation: generation), .init(
            ownerSubject: owner, backupNamespace: context.backupNamespace,
            storageAccountBinding: context.storageAccountBinding
        ))
    }
}

private struct NeverJournalTokenProvider: GoogleDriveBackupAccessTokenProvider {
    func authorization() async throws -> GoogleDriveBackupAuthorization {
        throw GoogleDrivePasskeyBackupError.authorizationFailed
    }
}
