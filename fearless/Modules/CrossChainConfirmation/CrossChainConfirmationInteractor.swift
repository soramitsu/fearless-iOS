import UIKit
import SSFXCM
import RobinHood
import BigInt
import SSFModels
import SSFUtils

protocol CrossChainConfirmationInteractorOutput: AnyObject {
    func didTransfer(result: Result<ReviewedCrossChainSubmissionResult, Error>)
    /// The same transfer was handed to the network earlier and its outcome is unresolved. Nothing was signed or sent.
    /// `records` holds every such attempt, newest first.
    func didFindUnresolvedSubmission(_ records: [ReviewedCrossChainSubmissionRecord])
}

final class CrossChainConfirmationInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainConfirmationInteractorOutput?

    private let teleportData: CrossChainConfirmationData
    private let submissionAuthorizer: ReviewedCrossChainSubmissionAuthorizing
    private let journal: ReviewedCrossChainSubmissionJournaling
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let mutationsEnabled: () -> Bool
    private let now: () -> Date

    init(
        teleportData: CrossChainConfirmationData,
        submissionAuthorizer: ReviewedCrossChainSubmissionAuthorizing,
        journal: ReviewedCrossChainSubmissionJournaling = ReviewedCrossChainSubmissionJournal.shared,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        mutationsEnabled: @escaping () -> Bool = {
            MultiChainFeaturePolicy.current.crossChainMutationsEnabled
        },
        now: @escaping () -> Date = Date.init
    ) {
        self.teleportData = teleportData
        self.submissionAuthorizer = submissionAuthorizer
        self.journal = journal
        self.operationQueue = operationQueue
        self.logger = logger
        self.mutationsEnabled = mutationsEnabled
        self.now = now
    }

    // MARK: - Private methods

    private var summary: String {
        [
            teleportData.displayAmount,
            teleportData.originChainAsset.asset.symbolUppercased,
            "\(teleportData.originChainAsset.chain.name) → \(teleportData.destChainModel.name)",
            teleportData.recipientAddress
        ].joined(separator: " ")
    }

    private func submitAuthorized(
        _ authorized: ReviewedCrossChainAuthorizedSubmission
    ) async throws -> ReviewedCrossChainSubmissionResult {
        let startedAt = now()
        var record = ReviewedCrossChainSubmissionRecord(
            transferKey: authorized.transferKey,
            attemptId: UUID().uuidString,
            intentSha256: authorized.intentSha256,
            status: .submitting,
            extrinsicHash: nil,
            blockHash: nil,
            summary: summary,
            createdAt: startedAt,
            updatedAt: startedAt
        )
        // Written before the extrinsic can leave the app: a crash or kill after this point still leaves a record
        // that asks the user before the same transfer is sent again.
        do {
            try journal.save(record)
        } catch {
            throw ReviewedCrossChainDispatchError.journalUnavailable
        }

        let receipt: ReviewedCrossChainSubmissionReceipt
        do {
            // This synchronous guard is deliberately adjacent to submit:
            // no await or other mutable work may be inserted between them.
            try authorized.finalGuard()
            receipt = try await authorized.executor.submit(authorized.builder)
        } catch {
            if Self.provesNothingWasSent(error) {
                // Only this attempt is withdrawn. An earlier attempt of the same transfer that may have reached the
                // network keeps asking before the transfer is sent again.
                journal.remove(record)
                throw error
            }
            record.status = .inDoubt
            record.updatedAt = now()
            try? journal.save(record)
            throw ReviewedCrossChainDispatchError.submissionInDoubt
        }

        record.status = .inDoubt
        record.extrinsicHash = receipt.extrinsicHash
        record.updatedAt = now()
        try? journal.save(record)

        switch await authorized.executor.dispatchOutcome(for: receipt) {
        case .failed:
            // The runtime rejected this attempt in a finalized block: it burned nothing and cannot be included again.
            // Earlier attempts keep their records.
            journal.remove(record)
            throw ReviewedCrossChainDispatchError.extrinsicFailed(extrinsicHash: receipt.extrinsicHash)
        case let .succeeded(blockHash):
            record.status = .awaitingBridge
            record.blockHash = blockHash
            record.updatedAt = now()
            try? journal.save(record)
            return .awaitingBridge(extrinsicHash: receipt.extrinsicHash)
        case .unknown:
            return .unconfirmed(extrinsicHash: receipt.extrinsicHash)
        }
    }

    /// Local authorization refusals and explicit author-RPC pool rejections happen before admission.
    /// An already-imported transaction (1013) or an unclassified RPC error can follow acceptance.
    static func provesNothingWasSent(_ error: Error) -> Bool {
        if error is ReviewedCrossChainSubmissionError || error is MutationAuthorizationError {
            return true
        }
        guard let rpcError = error as? JSONRPCError else { return false }
        // Substrate author/error.rs: format/verification failures and explicit pool refusals.
        // Keep this platform-owned classification aligned with the reviewed RPC contract.
        return [1001, 1002, 1010, 1011, 1012, 1014, 1015, 1016, 1018, 1019, 1020, 1021]
            .contains(rpcError.code)
    }
}

// MARK: - CrossChainConfirmationInteractorInput

extension CrossChainConfirmationInteractor: CrossChainConfirmationInteractorInput {
    func setup(with output: CrossChainConfirmationInteractorOutput) {
        self.output = output
    }

    func submit(confirmingRepeat: Bool) {
        Task {
            do {
                let authorized = try await submissionAuthorizer.authorize()
                guard mutationsEnabled() else {
                    throw ReviewedCrossChainSubmissionError.actionsPaused
                }
                let unresolved: [ReviewedCrossChainSubmissionRecord]
                do {
                    unresolved = try journal.unresolved(for: authorized.transferKey, now: now())
                } catch {
                    // An attempt of this transfer may be among the records that cannot be read: fail closed.
                    throw ReviewedCrossChainDispatchError.journalUnreadable
                }
                if !confirmingRepeat, !unresolved.isEmpty {
                    await MainActor.run {
                        self.output?.didFindUnresolvedSubmission(unresolved)
                    }
                    return
                }
                let result = try await submitAuthorized(authorized)
                await MainActor.run {
                    self.output?.didTransfer(result: .success(result))
                }
            } catch {
                await MainActor.run {
                    self.output?.didTransfer(result: .failure(error))
                }
            }
        }
    }
}
