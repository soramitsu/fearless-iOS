import Foundation
import RobinHood
import SSFUtils
import XCTest
@testable import fearless

final class CovGOperationUtilitiesTests: XCTestCase {
    func testLongrunOperationDeliversResultAndCancelsUnderlyingWork() throws {
        let longrun = CovGLongrun()
        let operation = LongrunOperation(longrun: AnyLongrun(longrun: longrun))
        XCTAssertTrue(operation.isAsynchronous)
        OperationQueue().addOperation(operation)
        waitUntil { longrun.completion != nil }
        longrun.completion?(.success(81))
        waitUntil { operation.isFinished }
        XCTAssertEqual(try CovGOperationFixtures.result(operation), 81)

        let cancelled = LongrunOperation(longrun: AnyLongrun(longrun: CovGLongrun()))
        let pending = CovGLongrun()
        let running = LongrunOperation(longrun: AnyLongrun(longrun: pending))
        running.start()
        waitUntil { pending.completion != nil }
        running.cancel()
        XCTAssertEqual(pending.cancelCount, 1)
        XCTAssertTrue(running.isFinished)
        XCTAssertFalse(running.isExecuting)
        cancelled.cancel()
        cancelled.start()
        XCTAssertTrue(cancelled.isFinished)
        XCTAssertNil(cancelled.result)

        let preset = LongrunOperation(longrun: AnyLongrun(longrun: CovGLongrun()))
        preset.result = .success(5)
        preset.start()
        XCTAssertTrue(preset.isFinished)
        XCTAssertEqual(try CovGOperationFixtures.result(preset), 5)
    }

    func testEmptyStreamableSourceReportsZeroChangesOnQueueOrInline() {
        let source = fearless.EmptyStreamableSource<AccountInfoStorageWrapper>()
        var inline: [Int] = []
        source.fetchHistory(runningIn: nil) { inline.append((try? $0?.get()) ?? -1) }
        source.refresh(runningIn: nil) { inline.append((try? $0?.get()) ?? -1) }
        XCTAssertEqual(inline, [0, 0])
        let done = expectation(description: "queued history")
        done.expectedFulfillmentCount = 2
        source.fetchHistory(runningIn: .main) { XCTAssertEqual(try? $0?.get(), 0); done.fulfill() }
        source.refresh(runningIn: .main) { XCTAssertEqual(try? $0?.get(), 0); done.fulfill() }
        wait(for: [done], timeout: 5)
        source.fetchHistory(runningIn: nil, commitNotificationBlock: nil)
        source.refresh(runningIn: nil, commitNotificationBlock: nil)
    }

    func testBalanceCacheWrapperPersistsMapsAndSingleValues() throws {
        let repository = InMemoryDataProviderRepository<AccountInfoStorageWrapper>()
        let wrapper = BalanceRepositoryCacheWrapper(
            logger: Logger.shared, repository: AnyDataProviderRepository(repository), operationManager: OperationManager()
        )
        let info = AccountInfo(ethBalance: 12)
        try wrapper.save(map: ["first": info, "second": nil])
        waitUntil { (try? CovGOperationFixtures.run(repository.fetchCountOperation())) == 2 }
        let stored = try CovGOperationFixtures.run(repository.fetchOperation(by: { "first" }, options: RepositoryFetchOptions()))
        XCTAssertEqual(try JSONDecoder().decode(AccountInfo.self, from: XCTUnwrap(stored).data), info)
        try wrapper.save(data: AccountInfo(ethBalance: 13), identifier: "third")
        waitUntil { (try? CovGOperationFixtures.run(repository.fetchCountOperation())) == 3 }
    }

    func testSubstrateOperationFactoryBuildsChainRequestForEndpoint() throws {
        let factory = SubstrateOperationFactory(logger: Logger.shared)
        let operation = try factory.fetchChainOperation(XCTUnwrap(URL(string: "wss://node.invalid")))
        let list = try XCTUnwrap(operation as? JSONRPCListOperation<String>)
        XCTAssertEqual(list.method, RPCMethod.chain)
        XCTAssertTrue(factory.logger is Logger)
    }

    private func waitUntil(_ predicate: () -> Bool) {
        let deadline = Date().addingTimeInterval(10)
        while !predicate(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
        XCTAssertTrue(predicate())
    }
}

private final class CovGLongrun: Longrunable {
    typealias ResultType = Int
    private let lock = NSLock()
    private var storedCompletion: ((Result<Int, Error>) -> Void)?
    private var cancels = 0

    var completion: ((Result<Int, Error>) -> Void)? {
        lock.lock(); defer { lock.unlock() }; return storedCompletion
    }

    var cancelCount: Int {
        lock.lock(); defer { lock.unlock() }; return cancels
    }

    func start(with completionClosure: @escaping (Result<Int, Error>) -> Void) {
        lock.lock(); storedCompletion = completionClosure; lock.unlock()
    }

    func cancel() {
        lock.lock(); cancels += 1; lock.unlock()
    }
}
