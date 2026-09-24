import Foundation

enum PasskeyBackupVerifiedPromotionError: Error, Equatable {
    case candidateMismatch
    case operationNotAttempted
    case unresolvedCommit
}

/// A promotion returns evidence only after the exact journaled ciphertext has been uploaded,
/// downloaded, decrypted with a verified local PRF and checked against original wallet keys.
/// A successful owner CAS is checked again through the authenticated head and Drive readback.
/// This is a disabled candidate until a real app-owned plaintext wallet verifier is supplied.
final class PasskeyBackupVerifiedGenerationPromotion {
    private let storage: GoogleDrivePasskeyGenerationStorage
    private let journal: PasskeyBackupGenerationJournal
    private let cryptographicVerifier: PasskeyBackupCryptoVerifier
    private let ownerHeadSource: PasskeyBackupOwnerHeadSource
    private let ownerGenerationClient: HTTPPasskeyBackupOwnerGenerationClient
    private let nowUnixSeconds: () -> Int64
    private let isReleaseEnabled: Bool

    init(
        storage: GoogleDrivePasskeyGenerationStorage,
        journal: PasskeyBackupGenerationJournal,
        cryptographicVerifier: PasskeyBackupCryptoVerifier,
        ownerHeadSource: PasskeyBackupOwnerHeadSource,
        ownerGenerationClient: HTTPPasskeyBackupOwnerGenerationClient,
        nowUnixSeconds: @escaping () -> Int64 = { Int64(Date().timeIntervalSince1970) },
        isReleaseEnabled: Bool = PasskeyBackupReleaseConfig.isPasskeyBackupEnabled
    ) {
        self.storage = storage
        self.journal = journal
        self.cryptographicVerifier = cryptographicVerifier
        self.ownerHeadSource = ownerHeadSource
        self.ownerGenerationClient = ownerGenerationClient
        self.nowUnixSeconds = nowUnixSeconds
        self.isReleaseEnabled = isReleaseEnabled
    }

    private struct PromotionContext {
        let prepared: PasskeyBackupGenerationJournalEntry
        let reference: PasskeyBackupOperationReference
        let scope: PasskeyBackupGenerationJournalScope
        let ownerSession: PasskeyBackupOwnerSession
        let verifiedPRF: PasskeyBackupVerifiedLocalPRF
        let expectedWallet: PasskeyBackupExpectedWalletIdentity
    }

    /// A nil candidate resumes the same durable operation after an interrupted request. On an
    /// ambiguous commit outcome, the caller must resume this operation; it must not make a new
    /// generation or delete the prior decryptable head.
    func promote(
        operationID: String,
        ownerSession: PasskeyBackupOwnerSession,
        verifiedPRF: PasskeyBackupVerifiedLocalPRF,
        expectedWallet: PasskeyBackupExpectedWalletIdentity,
        candidate suppliedCandidate: GoogleDrivePasskeyGenerationStorage.Candidate? = nil
    ) async throws -> PasskeyBackupLocallyVerifiedHead {
        try requireAuthorized(ownerSession)
        let binding = try await storage.selectedAccountBinding()
        let scope = PasskeyBackupGenerationJournalScope(
            ownerSubject: ownerSession.ownerSubject,
            backupNamespace: ownerSession.backupNamespace,
            storageAccountBinding: binding
        )
        let prepared = try prepare(
            operationID: operationID, scope: scope, expectedWallet: expectedWallet,
            suppliedCandidate: suppliedCandidate
        )
        let context = try PromotionContext(
            prepared: prepared,
            reference: PasskeyBackupOperationReference(journalEntry: prepared),
            scope: scope, ownerSession: ownerSession, verifiedPRF: verifiedPRF,
            expectedWallet: expectedWallet
        )
        let initialHead = try await ownerHeadSource.readHead(session: ownerSession)
        try requireAuthorized(ownerSession)
        let status = try await ownerGenerationClient.operationStatus(
            session: ownerSession, reference: context.reference
        )
        switch status {
        case let .committed(descriptor):
            guard prepared.createAttempted, prepared.commitAttempted else {
                throw PasskeyBackupVerifiedPromotionError.operationNotAttempted
            }
            return try await verifyCommitted(descriptor: descriptor, context: context)
        case .absent:
            guard !prepared.commitAttempted else {
                throw PasskeyBackupVerifiedPromotionError.unresolvedCommit
            }
            return try await promoteAbsent(context: context, initialHead: initialHead)
        }
    }

    private func promoteAbsent(
        context: PromotionContext, initialHead: PasskeyBackupAuthenticatedHead
    ) async throws -> PasskeyBackupLocallyVerifiedHead {
        let prepared = context.prepared
        let candidate = try storage.prepareCandidate(
            fileID: prepared.fileID,
            generation: PasskeyBackupGenerationV1Format.decode(
                prepared.bytes, expectedContext: prepared.context, expectedSha256: prepared.sha256
            )
        )
        let metadata = try PasskeyBackupGenerationMetadata(
            operationID: context.reference.operationID, candidate: candidate,
            authenticatedHead: initialHead
        )
        let verifier = CryptographicWalletVerifier(
            cryptographicVerifier: cryptographicVerifier, verifiedPRF: context.verifiedPRF
        )
        let evidence = try await PasskeyBackupGenerationCoordinator(
            storage: storage, journal: journal, verifier: verifier
        ).verifyPreparedGeneration(
            operationID: context.reference.operationID, authenticatedScope: context.scope,
            expectedWallet: context.expectedWallet, candidate: candidate
        )
        guard evidence.fileID == context.reference.driveFileID,
              evidence.sha256 == context.reference.bundleSHA256,
              evidence.context == context.reference.context else {
            throw PasskeyBackupVerifiedPromotionError.candidateMismatch
        }
        try await requireUnchangedHead(initialHead, ownerSession: context.ownerSession)
        let grant = try await ownerGenerationClient.grant(
            session: context.ownerSession, metadata: metadata
        )
        try await requireUnchangedHead(initialHead, ownerSession: context.ownerSession)
        guard try journal.admitFirstCommitAttempt(
            operationID: context.reference.operationID, expectedScope: context.scope
        ) else {
            throw PasskeyBackupVerifiedPromotionError.unresolvedCommit
        }
        return try await commitVerified(context: context, metadata: metadata, grant: grant, evidence: evidence)
    }

    private func commitVerified(
        context: PromotionContext, metadata: PasskeyBackupGenerationMetadata,
        grant: PasskeyBackupGenerationGrant, evidence: PasskeyBackupLocallyVerifiedGeneration
    ) async throws -> PasskeyBackupLocallyVerifiedHead {
        let descriptor: PasskeyBackupHeadDescriptor
        do {
            descriptor = try await ownerGenerationClient.commit(
                session: context.ownerSession, metadata: metadata, grant: grant
            )
        } catch {
            if error is CancellationError {
                throw error
            }
            // The server may have committed before a lost response. Never retry a write here.
            guard case let .committed(confirmed) = try await ownerGenerationClient.operationStatus(
                session: context.ownerSession, reference: context.reference
            ) else {
                throw PasskeyBackupVerifiedPromotionError.unresolvedCommit
            }
            return try await verifyCommitted(
                descriptor: confirmed, context: context, priorEvidence: evidence
            )
        }
        return try await verifyCommitted(
            descriptor: descriptor, context: context, priorEvidence: evidence
        )
    }
}

private extension PasskeyBackupVerifiedGenerationPromotion {
    func prepare(
        operationID: String, scope: PasskeyBackupGenerationJournalScope,
        expectedWallet: PasskeyBackupExpectedWalletIdentity,
        suppliedCandidate: GoogleDrivePasskeyGenerationStorage.Candidate?
    ) throws -> PasskeyBackupGenerationJournalEntry {
        let existing = try journal.read(operationID: operationID, expectedScope: scope)
        if let suppliedCandidate = suppliedCandidate {
            guard scope.matches(suppliedCandidate.context) else {
                throw PasskeyBackupGenerationJournalError.scopeMismatch
            }
            let generation = try PasskeyBackupGenerationV1Format.decode(
                suppliedCandidate.bytes, expectedContext: suppliedCandidate.context,
                expectedSha256: suppliedCandidate.sha256
            )
            try requireWalletIdentity(generation, expectedWallet: expectedWallet)
            if let existing = existing {
                guard existing.fileID == suppliedCandidate.fileID,
                      existing.context == suppliedCandidate.context,
                      existing.sha256 == suppliedCandidate.sha256,
                      existing.bytes == suppliedCandidate.bytes else {
                    throw PasskeyBackupVerifiedPromotionError.candidateMismatch
                }
                return existing
            }
            return try journal.persistPrepared(
                operationID: operationID, candidate: suppliedCandidate, expectedScope: scope
            )
        }
        guard let existing = existing else {
            throw PasskeyBackupGenerationCoordinatorError.missingPreparedGeneration
        }
        let generation = try PasskeyBackupGenerationV1Format.decode(
            existing.bytes, expectedContext: existing.context, expectedSha256: existing.sha256
        )
        try requireWalletIdentity(generation, expectedWallet: expectedWallet)
        return existing
    }

    private func requireWalletIdentity(
        _ generation: PasskeyBackupGenerationV1,
        expectedWallet: PasskeyBackupExpectedWalletIdentity
    ) throws {
        guard generation.envelope.storageKey == expectedWallet.storageKey,
              generation.envelope.walletId == expectedWallet.walletId else {
            throw PasskeyBackupGenerationCoordinatorError.walletIdentityMismatch
        }
    }

    private func requireAuthorized(_ session: PasskeyBackupOwnerSession) throws {
        try PasskeyBackupReleaseConfig.validateEnabled(isReleaseEnabled)
        try Task.checkCancellation()
        try session.requireFresh(nowUnixSeconds: nowUnixSeconds())
    }

    private func requireUnchangedHead(
        _ initial: PasskeyBackupAuthenticatedHead,
        ownerSession: PasskeyBackupOwnerSession
    ) async throws {
        try requireAuthorized(ownerSession)
        let current = try await ownerHeadSource.readHead(session: ownerSession)
        guard current == initial else { throw PasskeyBackupAuthenticatedHeadError.headChanged }
        try await storage.requireSelectedAccount()
        try requireAuthorized(ownerSession)
    }

    private func verifyCommitted(
        descriptor: PasskeyBackupHeadDescriptor,
        context: PromotionContext,
        priorEvidence: PasskeyBackupLocallyVerifiedGeneration? = nil
    ) async throws -> PasskeyBackupLocallyVerifiedHead {
        try context.reference.requireDescriptor(descriptor)
        try requireAuthorized(context.ownerSession)
        let selected = try await ownerHeadSource.readHead(session: context.ownerSession)
        guard selected.head == descriptor else { throw PasskeyBackupAuthenticatedHeadError.headChanged }
        let evidence: PasskeyBackupLocallyVerifiedHead
        if let priorEvidence = priorEvidence {
            evidence = try await verifyPriorEvidence(
                priorEvidence, selected: selected, context: context
            )
        } else {
            evidence = try await PasskeyBackupHeadReadbackVerifier(
                storage: storage, cryptographicVerifier: cryptographicVerifier,
                nowUnixSeconds: nowUnixSeconds
            ).verifyCurrent(
                ownerHeadSource: ownerHeadSource, ownerSession: context.ownerSession,
                verifiedPRF: context.verifiedPRF, expectedWallet: context.expectedWallet
            )
        }
        guard evidence.headRevision == descriptor.headRevision,
              evidence.fileID == descriptor.driveFileID,
              evidence.sha256 == descriptor.bundleSha256 else {
            throw PasskeyBackupAuthenticatedHeadError.headChanged
        }
        try requireJournal(context)
        try await storage.requireSelectedAccount()
        try requireAuthorized(context.ownerSession)
        return evidence
    }

    private func verifyPriorEvidence(
        _ prior: PasskeyBackupLocallyVerifiedGeneration,
        selected: PasskeyBackupAuthenticatedHead,
        context: PromotionContext
    ) async throws -> PasskeyBackupLocallyVerifiedHead {
        let prepared = context.prepared
        let reference = context.reference
        guard prior.operationID == reference.operationID,
              prior.fileID == prepared.fileID, prior.sha256 == prepared.sha256,
              prior.context == prepared.context,
              prior.publicIdentitySha256 == context.expectedWallet.publicIdentitySha256,
              let downloaded = try await storage.readCurrentHead(selected),
              try PasskeyBackupGenerationV1Format.encode(downloaded) == prepared.bytes else {
            throw PasskeyBackupVerifiedPromotionError.candidateMismatch
        }
        let final = try await ownerHeadSource.readHead(session: context.ownerSession)
        guard final == selected, let head = selected.head else {
            throw PasskeyBackupAuthenticatedHeadError.headChanged
        }
        try await storage.requireSelectedAccount()
        return PasskeyBackupLocallyVerifiedHead(
            headRevision: head.headRevision, fileID: head.driveFileID,
            sha256: head.bundleSha256,
            publicIdentitySha256: prior.publicIdentitySha256
        )
    }

    private func requireJournal(_ context: PromotionContext) throws {
        let prepared = context.prepared
        guard let current = try journal.read(
            operationID: context.reference.operationID, expectedScope: context.scope
        ), current.createAttempted, current.commitAttempted, current.fileID == prepared.fileID,
        current.context == prepared.context, current.sha256 == prepared.sha256,
        current.bytes == prepared.bytes else {
            throw PasskeyBackupGenerationJournalError.invalidRecord
        }
    }

    private struct CryptographicWalletVerifier: PasskeyLocalWalletVerifier {
        let cryptographicVerifier: PasskeyBackupCryptoVerifier
        let verifiedPRF: PasskeyBackupVerifiedLocalPRF

        func decryptAndVerifyOriginalWallet(
            _ downloaded: PasskeyBackupGenerationV1,
            expectedIdentity: PasskeyBackupExpectedWalletIdentity
        ) async throws -> PasskeyBackupLocalWalletEvidence {
            try await cryptographicVerifier.verify(
                downloaded, verifiedPRF: verifiedPRF, expectedIdentity: expectedIdentity
            )
        }
    }
}
