import UIKit
import SSFXCM
import RobinHood
import BigInt
import SSFModels

protocol CrossChainConfirmationInteractorOutput: AnyObject {
    func didTransfer(result: Result<String, Error>)
}

final class CrossChainConfirmationInteractor {
    // MARK: - Private properties

    private weak var output: CrossChainConfirmationInteractorOutput?

    private let teleportData: CrossChainConfirmationData
    private let submissionAuthorizer: ReviewedCrossChainSubmissionAuthorizing
    private let operationQueue: OperationQueue
    private let logger: LoggerProtocol
    private let mutationsEnabled: () -> Bool

    init(
        teleportData: CrossChainConfirmationData,
        submissionAuthorizer: ReviewedCrossChainSubmissionAuthorizing,
        operationQueue: OperationQueue,
        logger: LoggerProtocol,
        mutationsEnabled: @escaping () -> Bool = {
            MultiChainFeaturePolicy.current.crossChainMutationsEnabled
        }
    ) {
        self.teleportData = teleportData
        self.submissionAuthorizer = submissionAuthorizer
        self.operationQueue = operationQueue
        self.logger = logger
        self.mutationsEnabled = mutationsEnabled
    }

    // MARK: - Private methods
}

// MARK: - CrossChainConfirmationInteractorInput

extension CrossChainConfirmationInteractor: CrossChainConfirmationInteractorInput {
    func setup(with output: CrossChainConfirmationInteractorOutput) {
        self.output = output
    }

    func submit() {
        Task {
            do {
                let authorized = try await submissionAuthorizer.authorize()
                guard mutationsEnabled() else {
                    throw ReviewedCrossChainSubmissionError.actionsPaused
                }
                // This synchronous guard is deliberately adjacent to submit:
                // no await or other mutable work may be inserted between them.
                try authorized.finalGuard()
                let result = try await authorized.executor.submit(authorized.builder)
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
