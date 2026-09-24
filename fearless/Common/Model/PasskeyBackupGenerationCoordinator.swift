import Foundation

enum PasskeyBackupGenerationCoordinatorError: Error, Equatable {
    case missingPreparedGeneration
    case generationUnavailable
    case downloadedGenerationMismatch
    case walletIdentityMismatch
    case localVerificationFailed
}

/// Supplied independently of Drive and the local journal by authenticated owner/wallet state.
struct PasskeyBackupExpectedWalletIdentity: CustomStringConvertible, CustomDebugStringConvertible {
    let storageKey: String
    let walletId: String
    let publicIdentitySha256: String

    init(storageKey: String, walletId: String, publicIdentitySha256: String) throws {
        self.storageKey = try PasskeyBackupContract.validateStorageKey(storageKey)
        self.walletId = try PasskeyBackupContract.validateWalletId(walletId)
        guard Self.isDigest(publicIdentitySha256) else {
            throw PasskeyBackupGenerationCoordinatorError.walletIdentityMismatch
        }
        self.publicIdentitySha256 = publicIdentitySha256
    }

    var description: String { "PasskeyBackupExpectedWalletIdentity(<redacted>)" }
    var debugDescription: String { description }

    fileprivate static func isDigest(_ value: String) -> Bool {
        value.utf8.count == 64 && value.utf8.allSatisfy { (48 ... 57).contains($0) || (97 ... 102).contains($0) }
    }
}

/// An implementation must unwrap a credential locally, decrypt the envelope, derive original
/// public identities, check signing with the original key and verify that key export still works.
/// This protocol deliberately has no default or metadata-only implementation.
protocol PasskeyLocalWalletVerifier {
    func decryptAndVerifyOriginalWallet(
        _ downloaded: PasskeyBackupGenerationV1,
        expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyBackupLocalWalletEvidence
}

/// The coordinator checks every field; a verifier must create this only after its local checks.
struct PasskeyBackupLocalWalletEvidence: CustomStringConvertible, CustomDebugStringConvertible {
    let storageKey: String
    let walletId: String
    let publicIdentitySha256: String
    let decryptionVerified: Bool
    let originalKeySigningVerified: Bool
    let originalKeyExportVerified: Bool

    var description: String { "PasskeyBackupLocalWalletEvidence(<redacted>)" }
    var debugDescription: String { description }
}

/// The app must derive original public identities from decrypted keys, then prove signing and export.
/// Neither generation metadata nor a Google account is a valid implementation of this contract.
protocol PasskeyBackupPlaintextWalletVerifier {
    func verifyOriginalWallet(
        _ plaintextBackup: Data,
        expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyBackupLocalWalletEvidence
}

/// Local crypto half of generation verification. Owner authentication, exact-head retrieval,
/// a live credential assertion and wallet installation remain separate release gates.
final class PasskeyBackupGenerationCryptographicVerifier {
    private let walletVerifier: PasskeyBackupPlaintextWalletVerifier
    private let envelopeCryptography: PasskeyBackupEnvelopeCryptography
    private let keyWrapper: PasskeyBackupCredentialKeyWrapper

    init(
        walletVerifier: PasskeyBackupPlaintextWalletVerifier,
        envelopeCryptography: PasskeyBackupEnvelopeCryptography = AESGCMPasskeyBackupEnvelopeCryptography(),
        keyWrapper: PasskeyBackupCredentialKeyWrapper = PasskeyBackupCredentialKeyWrapper()
    ) {
        self.walletVerifier = walletVerifier
        self.envelopeCryptography = envelopeCryptography
        self.keyWrapper = keyWrapper
    }

    func verify(
        _ generation: PasskeyBackupGenerationV1,
        verifiedPRF: PasskeyBackupVerifiedLocalPRF,
        expectedIdentity: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyBackupLocalWalletEvidence {
        try Task.checkCancellation()
        let envelope = generation.envelope
        guard verifiedPRF.storageKey == expectedIdentity.storageKey,
              envelope.storageKey == expectedIdentity.storageKey,
              envelope.walletId == expectedIdentity.walletId else {
            throw PasskeyBackupGenerationCoordinatorError.walletIdentityMismatch
        }
        let metadata = try envelope.envelopeMetadata()
        let credentialID = Self.base64URL(verifiedPRF.credentialID)
        let context = try PasskeyBackupKeyWrapperContext(
            ownerSubject: generation.context.ownerSubject,
            credentialId: credentialID,
            keyEpoch: generation.context.keyEpoch,
            envelopeMetadata: metadata
        )
        guard let record = generation.wrappers.first(where: { $0.context.credentialId == credentialID }),
              record.context == context, record.prfSalt == verifiedPRF.prfSalt else {
            throw PasskeyBackupGenerationCoordinatorError.localVerificationFailed
        }
        let provider = try PasskeyBackupVerifiedPRFKeyProvider(
            verifiedPRF: verifiedPRF, record: record,
            expectedContext: context, keyWrapper: keyWrapper
        )
        var plaintext: Data
        do {
            var backupKey = try await provider.backupKey(for: metadata)
            defer { backupKey.resetBytes(in: 0 ..< backupKey.count) }
            plaintext = try envelopeCryptography.decrypt(
                envelope.encryptedPayload, metadata: metadata, key: backupKey
            )
        }
        defer { plaintext.resetBytes(in: 0 ..< plaintext.count) }
        try Task.checkCancellation()
        let evidence = try await walletVerifier.verifyOriginalWallet(
            plaintext, expectedIdentity: expectedIdentity
        )
        try Task.checkCancellation()
        guard evidence.storageKey == expectedIdentity.storageKey,
              evidence.walletId == expectedIdentity.walletId,
              evidence.publicIdentitySha256 == expectedIdentity.publicIdentitySha256,
              evidence.decryptionVerified, evidence.originalKeySigningVerified,
              evidence.originalKeyExportVerified else {
            throw PasskeyBackupGenerationCoordinatorError.localVerificationFailed
        }
        return evidence
    }

    private static func base64URL(_ bytes: Data) -> String {
        bytes.base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}

/// Evidence of a local round trip only. It is not an owner-head update or backup-complete state.
struct PasskeyBackupLocallyVerifiedGeneration: CustomStringConvertible, CustomDebugStringConvertible {
    let operationID: String
    let fileID: String
    let context: PasskeyBackupGenerationV1.Context
    let sha256: String
    let publicIdentitySha256: String

    var description: String { "PasskeyBackupLocallyVerifiedGeneration(<redacted>)" }
    var debugDescription: String { description }
}

/// One durable create attempt followed by exact-ID reconciliation and mandatory local verification.
final class PasskeyBackupGenerationCoordinator {
    private let storage: GoogleDrivePasskeyGenerationStorage
    private let journal: PasskeyBackupGenerationJournal
    private let verifier: PasskeyLocalWalletVerifier

    init(
        storage: GoogleDrivePasskeyGenerationStorage,
        journal: PasskeyBackupGenerationJournal,
        verifier: PasskeyLocalWalletVerifier
    ) {
        self.storage = storage
        self.journal = journal
        self.verifier = verifier
    }

    /// `authenticatedScope` and `expectedWallet` must come from current owner authority, never
    /// from the candidate or journal. A nil candidate resumes a previously prepared operation.
    func verifyPreparedGeneration(
        operationID: String,
        authenticatedScope: PasskeyBackupGenerationJournalScope,
        expectedWallet: PasskeyBackupExpectedWalletIdentity,
        candidate suppliedCandidate: GoogleDrivePasskeyGenerationStorage.Candidate? = nil
    ) async throws -> PasskeyBackupLocallyVerifiedGeneration {
        try Task.checkCancellation()
        let (candidate, prepared) = try prepare(
            operationID: operationID, authenticatedScope: authenticatedScope,
            expectedWallet: expectedWallet, suppliedCandidate: suppliedCandidate
        )
        if !prepared.createAttempted {
            _ = try await storage.createCandidate(
                candidate, operationID: operationID, journal: journal, expectedScope: authenticatedScope
            )
        }
        try Task.checkCancellation()
        let current = try journal.read(operationID: operationID, expectedScope: authenticatedScope)
        guard current?.createAttempted == true else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        let downloaded = try await readExact(prepared, expectedWallet: expectedWallet)
        let evidence = try await verifyLocal(downloaded, expectedWallet: expectedWallet)
        // A verifier may suspend while the account or app-private journal changes.
        guard let confirmed = try journal.read(operationID: operationID, expectedScope: authenticatedScope),
              confirmed.createAttempted, confirmed.fileID == prepared.fileID,
              confirmed.context == prepared.context, confirmed.sha256 == prepared.sha256,
              confirmed.bytes == prepared.bytes else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        try await storage.requireSelectedAccount()
        try Task.checkCancellation()
        return PasskeyBackupLocallyVerifiedGeneration(
            operationID: operationID, fileID: prepared.fileID, context: prepared.context,
            sha256: prepared.sha256, publicIdentitySha256: evidence.publicIdentitySha256
        )
    }

    private func prepare(
        operationID: String,
        authenticatedScope: PasskeyBackupGenerationJournalScope,
        expectedWallet: PasskeyBackupExpectedWalletIdentity,
        suppliedCandidate: GoogleDrivePasskeyGenerationStorage.Candidate?
    ) throws -> (GoogleDrivePasskeyGenerationStorage.Candidate, PasskeyBackupGenerationJournalEntry) {
        let existing = try journal.read(operationID: operationID, expectedScope: authenticatedScope)
        let candidate: GoogleDrivePasskeyGenerationStorage.Candidate
        if let existing = existing {
            let generation = try PasskeyBackupGenerationV1Format.decode(
                existing.bytes, expectedContext: existing.context, expectedSha256: existing.sha256
            )
            candidate = try storage.prepareCandidate(fileID: existing.fileID, generation: generation)
        } else if let suppliedCandidate = suppliedCandidate {
            let generation = try PasskeyBackupGenerationV1Format.decode(
                suppliedCandidate.bytes, expectedContext: suppliedCandidate.context,
                expectedSha256: suppliedCandidate.sha256
            )
            candidate = try storage.prepareCandidate(fileID: suppliedCandidate.fileID, generation: generation)
        } else {
            throw PasskeyBackupGenerationCoordinatorError.missingPreparedGeneration
        }
        guard authenticatedScope.matches(candidate.context) else {
            throw PasskeyBackupGenerationJournalError.scopeMismatch
        }
        let expectedGeneration = try PasskeyBackupGenerationV1Format.decode(
            candidate.bytes, expectedContext: candidate.context, expectedSha256: candidate.sha256
        )
        try requireEnvelopeIdentity(expectedGeneration.envelope, expectedWallet: expectedWallet)
        let prepared = try journal.persistPrepared(
            operationID: operationID, candidate: suppliedCandidate ?? candidate, expectedScope: authenticatedScope
        )
        guard prepared.fileID == candidate.fileID, prepared.context == candidate.context,
              prepared.sha256 == candidate.sha256, prepared.bytes == candidate.bytes else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
        return (candidate, prepared)
    }

    private func readExact(
        _ prepared: PasskeyBackupGenerationJournalEntry,
        expectedWallet: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyBackupGenerationV1 {
        guard let downloaded = try await storage.readCandidate(
            fileID: prepared.fileID, expectedContext: prepared.context, expectedSha256: prepared.sha256
        ) else {
            throw PasskeyBackupGenerationCoordinatorError.generationUnavailable
        }
        let downloadedBytes = try PasskeyBackupGenerationV1Format.encode(downloaded)
        guard downloadedBytes == prepared.bytes,
              PasskeyBackupGenerationV1Format.sha256(downloadedBytes) == prepared.sha256 else {
            throw PasskeyBackupGenerationCoordinatorError.downloadedGenerationMismatch
        }
        try requireEnvelopeIdentity(downloaded.envelope, expectedWallet: expectedWallet)
        return downloaded
    }

    private func verifyLocal(
        _ downloaded: PasskeyBackupGenerationV1,
        expectedWallet: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyBackupLocalWalletEvidence {
        let evidence: PasskeyBackupLocalWalletEvidence
        do {
            evidence = try await verifier.decryptAndVerifyOriginalWallet(
                downloaded, expectedIdentity: expectedWallet
            )
        } catch {
            if error is CancellationError { throw error }
            throw PasskeyBackupGenerationCoordinatorError.localVerificationFailed
        }
        guard evidence.storageKey == expectedWallet.storageKey,
              evidence.walletId == expectedWallet.walletId,
              evidence.publicIdentitySha256 == expectedWallet.publicIdentitySha256,
              evidence.decryptionVerified, evidence.originalKeySigningVerified,
              evidence.originalKeyExportVerified else {
            throw PasskeyBackupGenerationCoordinatorError.localVerificationFailed
        }
        return evidence
    }

    private func requireEnvelopeIdentity(
        _ envelope: PasskeyBackupEncryptedRecord, expectedWallet: PasskeyBackupExpectedWalletIdentity
    ) throws {
        guard envelope.storageKey == expectedWallet.storageKey,
              envelope.walletId == expectedWallet.walletId else {
            throw PasskeyBackupGenerationCoordinatorError.walletIdentityMismatch
        }
    }
}

/// Read-only evidence that the exact owner-selected Drive generation was opened locally.
/// It does not install a wallet, authorize an owner, or establish that the head is still current.
struct PasskeyBackupLocallyVerifiedHead: CustomStringConvertible, CustomDebugStringConvertible {
    let headRevision: Int64
    let fileID: String
    let sha256: String
    let publicIdentitySha256: String

    var description: String { "PasskeyBackupLocallyVerifiedHead(<redacted>)" }
    var debugDescription: String { description }
}

/// A replacement-device readback boundary. The caller must obtain the head and expected wallet
/// identity from a fresh owner session, and must re-authorize the owner before wallet installation.
/// This type has no write, head-promotion, or wallet-installation operation.
final class PasskeyBackupHeadReadbackVerifier {
    private let storage: GoogleDrivePasskeyGenerationStorage
    private let cryptographicVerifier: PasskeyBackupGenerationCryptographicVerifier

    init(
        storage: GoogleDrivePasskeyGenerationStorage,
        cryptographicVerifier: PasskeyBackupGenerationCryptographicVerifier
    ) {
        self.storage = storage
        self.cryptographicVerifier = cryptographicVerifier
    }

    func verify(
        authenticatedHead: PasskeyBackupAuthenticatedHead,
        verifiedPRF: PasskeyBackupVerifiedLocalPRF,
        expectedWallet: PasskeyBackupExpectedWalletIdentity
    ) async throws -> PasskeyBackupLocallyVerifiedHead {
        try Task.checkCancellation()
        let selected = try authenticatedHead.currentReadParameters()
        guard let head = authenticatedHead.head else {
            throw PasskeyBackupAuthenticatedHeadError.missingHead
        }
        guard let downloaded = try await storage.readCurrentHead(authenticatedHead) else {
            throw PasskeyBackupGenerationCoordinatorError.generationUnavailable
        }
        try Task.checkCancellation()
        let evidence = try await cryptographicVerifier.verify(
            downloaded, verifiedPRF: verifiedPRF, expectedIdentity: expectedWallet
        )
        // Decryption and original-key checks can suspend while the selected Google identity changes.
        try await storage.requireSelectedAccount()
        try Task.checkCancellation()
        return PasskeyBackupLocallyVerifiedHead(
            headRevision: head.headRevision,
            fileID: selected.fileID, sha256: selected.sha256,
            publicIdentitySha256: evidence.publicIdentitySha256
        )
    }
}
