import BigInt
import SSFModels
import UIKit
import XCTest
@testable import fearless

// Doubles for the CrossChainConfirmation presenter, view, router and interactor tests (lane H).

final class CovHCCConfirmViewSpy: UIViewController, CrossChainConfirmationViewInput, FWTransferSealShowing {
    private(set) var viewModels: [CrossChainConfirmationViewModel] = []
    private(set) var starts = 0
    private(set) var stops = 0
    private(set) var stages: [FWSealStage] = []
    private(set) var breaks = 0

    func didReceive(viewModel: CrossChainConfirmationViewModel) { viewModels.append(viewModel) }
    func didStartLoading() { starts += 1 }
    func didStopLoading() { stops += 1 }
    func didReachTransferStage(_ stage: FWSealStage) { stages.append(stage) }
    func didBreakTransfer() { breaks += 1 }
}

final class CovHCCConfirmRouterSpy: CrossChainConfirmationRouterInput {
    struct Completion {
        let hash: String?
        let title: String
        let description: String
        let chainAsset: ChainAsset
    }

    struct Message {
        let message: String?
        let title: String
        let closeAction: String?
    }

    var presentsErrors = true
    private(set) var dismissed = 0
    private(set) var completions: [Completion] = []
    private(set) var errors: [Error] = []
    private(set) var messages: [Message] = []
    private(set) var sheets: [SheetAlertPresentableViewModel] = []
    private(set) var extrinsicFailures = 0

    func complete(on _: ControllerBackedProtocol?, hash: String?, title: String, description: String, chainAsset: ChainAsset) {
        completions.append(Completion(hash: hash, title: title, description: description, chainAsset: chainAsset))
    }

    func dismiss(view _: ControllerBackedProtocol?) { dismissed += 1 }

    func present(error: Error, from _: ControllerBackedProtocol?, locale _: Locale?) -> Bool {
        errors.append(error)
        return presentsErrors
    }

    func present(viewModel: SheetAlertPresentableViewModel, from _: ControllerBackedProtocol?) {
        sheets.append(viewModel)
    }

    func present(
        message: String?,
        title: String,
        closeAction: String?,
        from _: ControllerBackedProtocol?,
        actions _: [SheetAlertPresentableAction]
    ) {
        messages.append(Message(message: message, title: title, closeAction: closeAction))
    }

    func presentExtrinsicFailed(from _: ControllerBackedProtocol, locale _: Locale?) {
        extrinsicFailures += 1
    }
}

final class CovHCCConfirmInteractorSpy: CrossChainConfirmationInteractorInput {
    weak var output: CrossChainConfirmationInteractorOutput?
    private(set) var submissions: [Bool] = []

    func setup(with output: CrossChainConfirmationInteractorOutput) { self.output = output }
    func submit(confirmingRepeat: Bool) { submissions.append(confirmingRepeat) }
}

final class CovHCCConfirmSubmissionAuthorizer: SubmissionAuthorizing {
    let answer: Bool
    private(set) var requests = 0

    init(answer: Bool) {
        self.answer = answer
    }

    func authorizeSubmission(from _: ControllerBackedProtocol?, completion: @escaping (Bool) -> Void) {
        requests += 1
        completion(answer)
    }
}

final class CovHCCConfirmFeedback: FWFeedbackPlaying {
    private(set) var patterns: [FWFeedbackPattern] = []

    func play(_ pattern: FWFeedbackPattern) -> FWFeedbackOutcome {
        patterns.append(pattern)
        return FWFeedbackOutcome()
    }
}

enum CovHCCConfirmFixtureRecords {
    static func record(hash: String?, summary: String, createdAt: Date) -> ReviewedCrossChainSubmissionRecord {
        ReviewedCrossChainSubmissionRecord(
            transferKey: "transfer",
            attemptId: UUID().uuidString,
            intentSha256: String(repeating: "e", count: 64),
            status: .inDoubt,
            extrinsicHash: hash,
            blockHash: nil,
            summary: summary,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

final class CovHCCConfirmViewOutputSpy: CrossChainConfirmationViewOutput {
    private(set) var loads = 0
    private(set) var backs = 0
    private(set) var confirms = 0

    func didLoad(view _: CrossChainConfirmationViewInput) { loads += 1 }
    func backButtonDidTapped() { backs += 1 }
    func confirmButtonTapped() { confirms += 1 }
}

final class CovHCCConfirmPresentingSpy: UIViewController, ControllerBackedProtocol {
    private(set) var presented: [UIViewController] = []

    override func present(_ viewControllerToPresent: UIViewController, animated _: Bool, completion: (() -> Void)? = nil) {
        presented.append(viewControllerToPresent)
        completion?()
    }
}

final class CovHCCConfirmScreen: UIViewController, ControllerBackedProtocol {}

final class CovHCCConfirmNavigationSpy: UINavigationController {
    weak var presenting: UIViewController?
    private(set) var dismissals = 0

    override var presentingViewController: UIViewController? { presenting }

    override func dismiss(animated _: Bool, completion: (() -> Void)? = nil) {
        dismissals += 1
        completion?()
    }
}

final class CovHCCConfirmInteractorOutputSpy: CrossChainConfirmationInteractorOutput {
    private(set) var results: [Result<ReviewedCrossChainSubmissionResult, Error>] = []
    private(set) var unresolved: [[ReviewedCrossChainSubmissionRecord]] = []

    var errors: [Error] {
        results.compactMap { result in
            guard case let .failure(error) = result else { return nil }
            return error
        }
    }

    func didTransfer(result: Result<ReviewedCrossChainSubmissionResult, Error>) { results.append(result) }
    func didFindUnresolvedSubmission(_ records: [ReviewedCrossChainSubmissionRecord]) { unresolved.append(records) }
}

final class CovHCCConfirmExtrinsicExecutorSpy: ReviewedCrossChainExtrinsicExecuting {
    private(set) var submits = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure) async throws -> RuntimeDispatchInfo {
        RuntimeDispatchInfo(feeValue: BigUInt(1))
    }

    func submit(_: @escaping ExtrinsicBuilderClosure) async throws -> ReviewedCrossChainSubmissionReceipt {
        submits += 1
        return ReviewedCrossChainSubmissionReceipt(subscriptionId: "subscription", extrinsicHash: "0xhash")
    }

    func dispatchOutcome(for _: ReviewedCrossChainSubmissionReceipt) async -> ReviewedCrossChainDispatchOutcome {
        .unknown
    }
}

struct CovHCCConfirmFixedAuthorizer: ReviewedCrossChainSubmissionAuthorizing {
    let submission: ReviewedCrossChainAuthorizedSubmission

    func authorize() async throws -> ReviewedCrossChainAuthorizedSubmission {
        submission
    }
}

final class CovHCCConfirmJournal: ReviewedCrossChainSubmissionJournaling {
    var saveError: Error?
    var unresolvedError: Error?
    private(set) var saved: [ReviewedCrossChainSubmissionRecord] = []

    func unresolved(for _: String, now _: Date) throws -> [ReviewedCrossChainSubmissionRecord] {
        if let unresolvedError { throw unresolvedError }
        return []
    }

    func save(_ record: ReviewedCrossChainSubmissionRecord) throws {
        if let saveError { throw saveError }
        saved.append(record)
    }

    func remove(_: ReviewedCrossChainSubmissionRecord) {}
}
