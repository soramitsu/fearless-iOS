import RobinHood
import XCTest
@testable import fearless

final class OperationCombiningLifecycleTests: XCTestCase {
    func testCancellationDuringFactoryCreationNeverRunsReturnedWork() {
        let entered = expectation(description: "factory entered")
        let returned = expectation(description: "start returned")
        let completed = expectation(description: "completion")
        let release = DispatchSemaphore(value: 0)
        let queue = OperationQueue()
        queue.isSuspended = true
        var executed = false
        let child = ClosureOperation<Int> { executed = true; return 7 }
        let service = OperationCombiningService(operationManager: OperationManager(operationQueue: queue)) {
            entered.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
            return [CompoundOperationWrapper(targetOperation: child)]
        }
        DispatchQueue.global().async {
            service.start { result in
                if case .success = result { XCTFail("Cancelled construction must not succeed") }
                completed.fulfill()
            }
            returned.fulfill()
        }
        wait(for: [entered], timeout: 5)
        service.cancel()
        release.signal()
        wait(for: [returned], timeout: 5)
        XCTAssertTrue(child.isCancelled)
        queue.isSuspended = false
        queue.waitUntilAllOperationsAreFinished()
        wait(for: [completed], timeout: 5)
        XCTAssertFalse(executed)
        XCTAssertEqual(service.state, .finished)
    }

    func testStartRejectsSecondRunAndCancellationReachesOwnedOperations() {
        let queue = OperationQueue()
        queue.isSuspended = true
        defer { queue.isSuspended = false; queue.waitUntilAllOperationsAreFinished() }
        let child = ClosureOperation<Int> { 7 }
        var starts = 0
        let service = OperationCombiningService(operationManager: OperationManager(operationQueue: queue)) {
            starts += 1
            return [CompoundOperationWrapper(targetOperation: starts == 1 ? child : ClosureOperation { 8 })]
        }
        service.start { _ in }
        XCTAssertEqual(service.state, .running)
        var rejected = false
        service.start { result in
            if case let .failure(error) = result {
                rejected = error is OperationCombiningServiceError
            }
        }
        XCTAssertTrue(rejected)
        service.cancel()
        XCTAssertTrue(child.isCancelled)
        XCTAssertEqual(service.state, .finished)
    }

    func testConstructionFailureFinishesAndReportsExactlyOnce() {
        enum Expected: Error { case failed }
        let service =
            OperationCombiningService<Int>(operationManager: OperationManager(operationQueue: OperationQueue())) {
            throw Expected.failed
        }
        var failures = 0
        service.start {
            if case .failure = $0 {
                failures += 1
            }
        }
        XCTAssertEqual(failures, 1)
        XCTAssertEqual(service.state, .finished)
    }

    func testSuccessfulBatchedOperationsPreserveResultOrder() {
        let queue = OperationQueue()
        let service = OperationCombiningService(
            operationManager: OperationManager(operationQueue: queue),
            operationsPerBatch: 1
        ) {
            [3, 1, 2].map { value in CompoundOperationWrapper(targetOperation: ClosureOperation { value }) }
        }
        let done = expectation(description: "combined")
        service.start { result in
            XCTAssertEqual(try? result.get(), [3, 1, 2])
            done.fulfill()
        }
        wait(for: [done], timeout: 5)
        XCTAssertEqual(service.state, .finished)
    }
}
