import IrohaCrypto
import RobinHood
import SSFModels
import SSFUtils
import XCTest
@testable import fearless

final class CovFExtrinsicCallbacksTests: XCTestCase {
    func testSingleFeeDeliversSuccessFailureAndMissingResultOnRequestedQueue() throws {
        for mode in 0 ..< 3 {
            let fixture = try CovFExtrinsicFixture()
            let done = expectation(description: "fee \(mode)")
            fixture.service.estimateFee({ $0 }, runningIn: .main) { result in
                XCTAssertTrue(Thread.isMainThread)
                if mode == 0 { XCTAssertEqual(try? result.get().fee, "42") }
                else { XCTAssertNotNil(covFFailure(result)) }
                done.fulfill()
            }
            let result: Result<RuntimeDispatchInfo, Error>? = mode == 0 ? .success(RuntimeDispatchInfo(feeValue: 42))
                : mode == 1 ? .failure(fixture.error) : nil
            try fixture.manager.complete(result)
            wait(for: [done], timeout: 5)
            XCTAssertEqual(fixture.manager.batches.count, 1)
        }
    }

    func testIndexedFeesReplicateParentFailureForEveryExtrinsic() throws {
        for mode in 0 ..< 3 {
            let fixture = try CovFExtrinsicFixture()
            let done = expectation(description: "fees \(mode)")
            fixture.service.estimateFee({ builder, _ in builder }, runningIn: .main, numberOfExtrinsics: 2) { result in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(result.count, 2)
                if mode == 0 { XCTAssertEqual(result.compactMap { try? $0.get().fee }, ["42", "43"]) }
                else { result.forEach { XCTAssertNotNil(covFFailure($0)) } }
                done.fulfill()
            }
            let values: [FeeExtrinsicResult] = [.success(RuntimeDispatchInfo(feeValue: 42)), .success(RuntimeDispatchInfo(feeValue: 43))]
            let result: Result<[FeeExtrinsicResult], Error>? = mode == 0 ? .success(values) : mode == 1 ? .failure(fixture.error) : nil
            try fixture.manager.complete(result)
            wait(for: [done], timeout: 5)
        }
    }

    func testSingleSubmitDeliversHashAndBothFailureStates() throws {
        for mode in 0 ..< 3 {
            let fixture = try CovFExtrinsicFixture()
            let done = expectation(description: "submit \(mode)")
            fixture.service.submit({ $0 }, signer: CovFUnusedSigner(), runningIn: .main) { result in
                XCTAssertTrue(Thread.isMainThread)
                if mode == 0 { XCTAssertEqual(try? result.get(), "0xhash") }
                else { XCTAssertNotNil(covFFailure(result)) }
                done.fulfill()
            }
            let result: Result<String, Error>? = mode == 0 ? .success("0xhash") : mode == 1 ? .failure(fixture.error) : nil
            try fixture.manager.complete(result)
            wait(for: [done], timeout: 5)
        }
    }

    func testIndexedSubmissionReplicatesFailureAndKeepsSuccessfulOrder() throws {
        for mode in 0 ..< 3 {
            let fixture = try CovFExtrinsicFixture()
            let done = expectation(description: "submissions \(mode)")
            fixture.service.submit({ builder, _ in builder }, signer: CovFUnusedSigner(), runningIn: .main, numberOfExtrinsics: 2) { result in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(result.count, 2)
                if mode == 0 { XCTAssertEqual(result.compactMap { try? $0.get() }, ["first", "second"]) }
                else { result.forEach { XCTAssertNotNil(covFFailure($0)) } }
                done.fulfill()
            }
            let result: Result<[SubmitExtrinsicResult], Error>? = mode == 0 ? .success([.success("first"), .success("second")])
                : mode == 1 ? .failure(fixture.error) : nil
            try fixture.manager.complete(result)
            wait(for: [done], timeout: 5)
        }
    }

    func testSubmitAndWatchPreservesInnerResultAndMapsParentFailures() throws {
        for mode in 0 ..< 4 {
            let fixture = try CovFExtrinsicFixture()
            let done = expectation(description: "watch \(mode)")
            fixture.service.submitAndWatch({ $0 }, signer: CovFUnusedSigner(), runningIn: .main) { result, hash in
                XCTAssertTrue(Thread.isMainThread)
                XCTAssertEqual(hash, mode < 2 ? "0xextrinsic" : nil)
                if mode == 0 { XCTAssertEqual(try? result.get(), "finalized") }
                else {
                    let error = covFFailure(result)
                    if mode == 1 { XCTAssertEqual(error as NSError?, fixture.error) }
                    else { XCTAssertTrue(error is BaseOperationError) }
                }
                done.fulfill()
            }
            let inner: SubmitExtrinsicResult = mode == 0 ? .success("finalized") : .failure(fixture.error)
            let result: Result<SubmitAndWatchExtrinsicResult, Error>? = mode < 2 ? .success((inner, "0xextrinsic"))
                : mode == 2 ? .failure(fixture.error) : nil
            try fixture.manager.complete(result)
            wait(for: [done], timeout: 5)
        }
    }

    func testFeeProxyCoalescesInFlightRequestThenReplaysCachedSuccess() throws {
        let fixture = try CovFExtrinsicFixture()
        let proxy = ExtrinsicFeeProxy()
        let delegate = CovFFeeDelegate()
        proxy.delegate = delegate
        for _ in 0 ..< 2 { proxy.estimateFee(using: fixture.service, reuseIdentifier: "fee") { $0 } }
        XCTAssertEqual(fixture.manager.batches.count, 1)
        XCTAssertTrue(delegate.results.isEmpty)
        let done = expectation(description: "estimated")
        delegate.onResult = { done.fulfill() }
        try fixture.manager.complete(Result<RuntimeDispatchInfo, Error>.success(RuntimeDispatchInfo(feeValue: 42)))
        wait(for: [done], timeout: 5)
        delegate.onResult = nil
        proxy.estimateFee(using: fixture.service, reuseIdentifier: "fee") { $0 }
        XCTAssertEqual(fixture.manager.batches.count, 1)
        XCTAssertEqual(delegate.identifiers, ["fee", "fee"])
        XCTAssertEqual(delegate.results.compactMap { try? $0.get().fee }, ["42", "42"])
    }

    func testFeeProxyRetriesAfterFailureAndSeparatesIdentifiers() throws {
        let fixture = try CovFExtrinsicFixture()
        let proxy = ExtrinsicFeeProxy()
        let delegate = CovFFeeDelegate()
        proxy.delegate = delegate
        let done = expectation(description: "failed")
        delegate.onResult = { done.fulfill() }
        proxy.estimateFee(using: fixture.service, reuseIdentifier: "fee") { $0 }
        try fixture.manager.complete(Result<RuntimeDispatchInfo, Error>.failure(fixture.error))
        wait(for: [done], timeout: 5)
        XCTAssertThrowsError(try XCTUnwrap(delegate.results.first).get()) { XCTAssertEqual($0 as NSError, fixture.error) }
        proxy.estimateFee(using: fixture.service, reuseIdentifier: "fee") { $0 }
        proxy.estimateFee(using: fixture.service, reuseIdentifier: "other") { $0 }
        XCTAssertEqual(fixture.manager.batches.count, 3)
    }
}

private final class CovFExtrinsicFixture {
    let manager = CovFCallbackOperations()
    let error = NSError(domain: "extrinsic", code: 9)
    let service: ExtrinsicService
    init() throws {
        service = ExtrinsicService(accountId: CovFFixtures.account, chainFormat: .substrate(42), cryptoType: .sr25519,
                                   runtimeRegistry: try CovFFixtures.runtime(path: .activeEra, type: "u32", definitions: #"{"types":{}}"#),
                                   engine: MockConnection(), operationManager: manager)
    }
}

private final class CovFCallbackOperations: OperationManagerProtocol {
    var batches: [[Operation]] = []
    func enqueue(operations: [Operation], in _: OperationMode) { batches.append(operations) }
    func complete<T>(_ result: Result<T, Error>?) throws {
        let target = try XCTUnwrap(batches.last?.last as? BaseOperation<T>)
        XCTAssertNotNil(target.completionBlock)
        target.result = result
        target.completionBlock?()
    }
}

private final class CovFUnusedSigner: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol {
        XCTFail("Callback tests should not sign")
        throw NSError(domain: "unused signer", code: 1)
    }
}

private final class CovFFeeDelegate: ExtrinsicFeeProxyDelegate {
    var identifiers: [String] = []
    var results: [Result<RuntimeDispatchInfo, Error>] = []
    var onResult: (() -> Void)?
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>, for identifier: ExtrinsicFeeId) {
        identifiers.append(identifier)
        results.append(result)
        onResult?()
    }
}
