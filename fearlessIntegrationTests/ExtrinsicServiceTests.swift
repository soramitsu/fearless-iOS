import XCTest
import BigInt
@testable import fearless

final class ExtrinsicServiceTests: XCTestCase {
    func testEstimateFee_whenResultIsSuccessful_thenCachesResultForReuseIdentifier() {
        let service = ExtrinsicServiceSpy(results: [
            .success(RuntimeDispatchInfo(feeValue: 123))
        ])
        let proxy = ExtrinsicFeeProxy()
        let delegate = ExtrinsicFeeProxyDelegateSpy()
        proxy.delegate = delegate

        proxy.estimateFee(
            using: service,
            reuseIdentifier: "staking.bondExtra",
            setupBy: passthroughBuilder
        )
        proxy.estimateFee(
            using: service,
            reuseIdentifier: "staking.bondExtra",
            setupBy: passthroughBuilder
        )

        XCTAssertEqual(service.estimateFeeCallCount, 1)
        XCTAssertEqual(delegate.successFees, ["123", "123"])
        XCTAssertTrue(delegate.failures.isEmpty)
    }

    func testEstimateFee_whenRequestAlreadyLoading_thenDoesNotStartDuplicateRequest() {
        let service = ExtrinsicServiceSpy(completionMode: .manual)
        let proxy = ExtrinsicFeeProxy()
        let delegate = ExtrinsicFeeProxyDelegateSpy()
        proxy.delegate = delegate

        proxy.estimateFee(
            using: service,
            reuseIdentifier: "staking.payout",
            setupBy: passthroughBuilder
        )
        proxy.estimateFee(
            using: service,
            reuseIdentifier: "staking.payout",
            setupBy: passthroughBuilder
        )

        XCTAssertEqual(service.estimateFeeCallCount, 1)
        XCTAssertTrue(delegate.receivedIdentifiers.isEmpty)

        service.completeNext(with: .success(RuntimeDispatchInfo(feeValue: 456)))

        XCTAssertEqual(delegate.receivedIdentifiers, ["staking.payout"])
        XCTAssertEqual(delegate.successFees, ["456"])
    }

    func testEstimateFee_whenRequestFails_thenDoesNotCacheFailure() {
        let service = ExtrinsicServiceSpy(results: [
            .failure(ExtrinsicServiceTestError.failure),
            .success(RuntimeDispatchInfo(feeValue: 789))
        ])
        let proxy = ExtrinsicFeeProxy()
        let delegate = ExtrinsicFeeProxyDelegateSpy()
        proxy.delegate = delegate

        proxy.estimateFee(
            using: service,
            reuseIdentifier: "system.remark",
            setupBy: passthroughBuilder
        )
        proxy.estimateFee(
            using: service,
            reuseIdentifier: "system.remark",
            setupBy: passthroughBuilder
        )

        XCTAssertEqual(service.estimateFeeCallCount, 2)
        XCTAssertEqual(delegate.receivedIdentifiers, ["system.remark", "system.remark"])
        XCTAssertEqual(delegate.failures.count, 1)
        XCTAssertEqual(delegate.successFees, ["789"])
    }

    private var passthroughBuilder: ExtrinsicBuilderClosure {
        { builder in builder }
    }
}

private final class ExtrinsicServiceSpy: ExtrinsicServiceProtocol {
    enum CompletionMode {
        case immediate
        case manual
    }

    private(set) var estimateFeeCallCount = 0
    private var results: [FeeExtrinsicResult]
    private var pendingFeeCompletions: [EstimateFeeClosure] = []
    private let completionMode: CompletionMode

    init(
        results: [FeeExtrinsicResult] = [],
        completionMode: CompletionMode = .immediate
    ) {
        self.results = results
        self.completionMode = completionMode
    }

    func completeNext(with result: FeeExtrinsicResult) {
        pendingFeeCompletions.removeFirst()(result)
    }

    func estimateFee(
        _: @escaping ExtrinsicBuilderClosure,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        estimateFeeCallCount += 1

        switch completionMode {
        case .immediate:
            completionClosure(results.removeFirst())
        case .manual:
            pendingFeeCompletions.append(completionClosure)
        }
    }

    func estimateFee(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion _: @escaping EstimateFeeIndexedClosure
    ) {}

    func submit(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion _: @escaping ExtrinsicSubmitClosure
    ) {}

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion _: @escaping ExtrinsicSubmitIndexedClosure
    ) {}

    func submitAndWatch(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion _: @escaping ExtrinsicSubmitAndWatchClosure
    ) {}
}

private final class ExtrinsicFeeProxyDelegateSpy: ExtrinsicFeeProxyDelegate {
    private(set) var receivedIdentifiers: [ExtrinsicFeeId] = []
    private(set) var successFees: [String] = []
    private(set) var failures: [Error] = []

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for identifier: ExtrinsicFeeId) {
        receivedIdentifiers.append(identifier)

        switch result {
        case let .success(info):
            successFees.append(info.fee)
        case let .failure(error):
            failures.append(error)
        }
    }
}

private enum ExtrinsicServiceTestError: Error {
    case failure
}
