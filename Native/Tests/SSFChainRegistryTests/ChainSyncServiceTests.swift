import Foundation
import RobinHood
import SSFChainRegistry
import SSFModels
import SSFNetwork
import SSFUtils
import XCTest

final class ChainSyncServiceTests: XCTestCase {
    private enum Failure: Error { case request }

    func testImmediateCompletionAndCachedLookup() async {
        let chain = makeChain()
        let factory = ChainsFactory { ClosureOperation { [chain] } }
        let queue = InlineCompletionQueue()
        let service = makeService(factory: factory, queue: queue)
        let done = expectation(description: "immediate request completes")
        Task {
            defer { done.fulfill() }
            do {
                let models = try await service.getChainModels()
                XCTAssertEqual(models.map(\.chainId), [chain.chainId])
                let cached = try await service.getChainModel(for: chain.chainId)
                XCTAssertEqual(cached.chainId, chain.chainId)
                XCTAssertEqual(factory.requests, 1)
            } catch { XCTFail("Unexpected error: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
        XCTAssertTrue(queue.completionWasInstalled)
    }

    func testStandardQueueCompletesWithoutRetainingOperation() async {
        let chain = makeChain()
        weak var lastOperation: BaseOperation<[ChainModel]>?
        let factory = ChainsFactory {
            let operation = ClosureOperation { [chain] }
            lastOperation = operation
            return operation
        }
        let queue = OperationQueue()
        let service = makeService(factory: factory, queue: queue)
        let done = expectation(description: "standard queue completes")
        Task {
            defer { done.fulfill() }
            do {
                let models = try await service.getChainModels()
                XCTAssertEqual(models.map(\.chainId), [chain.chainId])
            } catch { XCTFail("Unexpected error: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
        // The operation must not retain its completion closure, which would retain the service.
        for _ in 0 ..< 50 where lastOperation != nil {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNil(lastOperation)
    }

    func testFailureResumesAndNextRequestCanSucceed() async {
        let chain = makeChain()
        var failed = false
        let factory = ChainsFactory {
            ClosureOperation {
                if !failed {
                    failed = true; throw Failure.request
                }
                return [chain]
            }
        }
        let service = makeService(factory: factory)
        let done = expectation(description: "failure and retry complete")
        Task {
            defer { done.fulfill() }
            do {
                _ = try await service.getChainModels()
                XCTFail("Expected the request error")
            } catch Failure.request {
            } catch { XCTFail("Unexpected error: \(error)") }
            do {
                let models = try await service.getChainModels()
                XCTAssertEqual(models.map(\.chainId), [chain.chainId])
                XCTAssertEqual(factory.requests, 2)
            } catch { XCTFail("Retry failed: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
    }

    func testCancelledOperationResumesWithError() async {
        await assertMissingResultResumes(cancelled: true)
    }

    func testCompletedOperationWithoutResultResumesWithError() async {
        await assertMissingResultResumes(cancelled: false)
    }

    private func assertMissingResultResumes(cancelled: Bool) async {
        let factory = ChainsFactory {
            let operation = BaseOperation<[ChainModel]>()
            if cancelled {
                operation.cancel()
            }
            return operation
        }
        let service = makeService(factory: factory)
        let done = expectation(description: "missing result completes")
        Task {
            defer { done.fulfill() }
            do {
                _ = try await service.getChainModels()
                XCTFail("Expected cancellation instead of a lost continuation")
            } catch BaseOperationError.parentOperationCancelled {
            } catch { XCTFail("Unexpected error: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
    }

    private func makeService(
        factory: ChainsFactory,
        queue: OperationQueue = InlineCompletionQueue()
    ) -> ChainSyncService {
        ChainSyncService(
            chainsUrl: URL(string: "https://unused.invalid/chains.json")!,
            operationQueue: queue,
            dataFetchFactory: factory,
            retryStrategy: NoRetry()
        )
    }

    private func makeChain() -> ChainModel {
        ChainModel(
            rank: 0,
            disabled: false,
            chainId: "test-chain",
            paraId: nil,
            name: "Test",
            xcm: nil,
            nodes: [],
            addressPrefix: 0,
            icon: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
    }
}

private struct NoRetry: ReconnectionStrategyProtocol {
    func reconnectAfter(attempt _: Int) -> TimeInterval? {
        nil
    }
}

private final class ChainsFactory: NetworkOperationFactoryProtocol {
    private let make: () -> BaseOperation<[ChainModel]>
    private(set) var requests = 0

    init(_ make: @escaping () -> BaseOperation<[ChainModel]>) {
        self.make = make
    }

    func fetchData<T: Decodable>(from _: URL) -> BaseOperation<T> {
        requests += 1
        return make() as! BaseOperation<T>
    }
}

/// A legal immediate completion order, without Foundation dispatching a second callback.
private final class InlineCompletionQueue: OperationQueue, @unchecked Sendable {
    private(set) var completionWasInstalled = true

    override func addOperations(_ ops: [Operation], waitUntilFinished _: Bool) {
        for operation in ops {
            addOperation(operation)
        }
    }

    override func addOperation(_ operation: Operation) {
        let completion = operation.completionBlock
        completionWasInstalled = completionWasInstalled && completion != nil
        operation.completionBlock = nil
        operation.start()
        completion?()
    }
}

final class ChainsTypesSyncServiceTests: XCTestCase {
    private enum Failure: Error { case request }

    private let validJSON = JSON.dictionaryValue(["chainId": .stringValue("test-chain")])

    func testImmediateTypesAndCachedLookup() async {
        let factory = TypesFactory { ClosureOperation { .arrayValue([self.validJSON]) } }
        let queue = InlineCompletionQueue()
        let service = makeService(factory: factory, queue: queue)
        let done = expectation(description: "types complete")
        Task {
            defer { done.fulfill() }
            do {
                let data = try await service.getTypes(for: "test-chain")
                let decoded = try JSONDecoder().decode(JSON.self, from: data)
                XCTAssertEqual(decoded, validJSON)
                let cached = try await service.getTypes(for: "test-chain")
                XCTAssertEqual(cached, data)
                XCTAssertEqual(factory.requests, 1)
            } catch { XCTFail("Unexpected error: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
        XCTAssertTrue(queue.completionWasInstalled)
    }

    func testCancelledTypesRequestResumes() async {
        let factory = TypesFactory {
            let operation = BaseOperation<JSON>()
            operation.cancel()
            return operation
        }
        let service = makeService(factory: factory)
        let done = expectation(description: "cancelled types complete")
        Task {
            defer { done.fulfill() }
            do {
                _ = try await service.getTypes(for: "test-chain")
                XCTFail("Expected cancellation")
            } catch BaseOperationError.parentOperationCancelled {
            } catch { XCTFail("Unexpected error: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
    }

    func testMalformedTypesRequestCanRetry() async {
        var first = true
        let factory = TypesFactory {
            ClosureOperation {
                if first {
                    first = false; return .stringValue("invalid")
                }
                return .arrayValue([self.validJSON])
            }
        }
        let service = makeService(factory: factory)
        let done = expectation(description: "types failure and retry complete")
        Task {
            defer { done.fulfill() }
            do {
                _ = try await service.getTypes(for: "test-chain")
                XCTFail("Expected malformed data error")
            } catch ChainsTypesSyncError.missingData {
            } catch { XCTFail("Unexpected error: \(error)") }
            do {
                let data = try await service.getTypes(for: "test-chain")
                XCTAssertEqual(try JSONDecoder().decode(JSON.self, from: data), validJSON)
            } catch { XCTFail("Retry failed: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
    }

    func testFailedTypesRequestResumes() async {
        let factory = TypesFactory { ClosureOperation { throw Failure.request } }
        let service = makeService(factory: factory)
        let done = expectation(description: "types failure completes")
        Task {
            defer { done.fulfill() }
            do {
                _ = try await service.getTypes(for: "test-chain")
                XCTFail("Expected request error")
            } catch Failure.request {
            } catch { XCTFail("Unexpected error: \(error)") }
        }
        await fulfillment(of: [done], timeout: 2)
    }

    private func makeService(
        factory: TypesFactory,
        queue: OperationQueue = InlineCompletionQueue()
    ) -> ChainsTypesSyncService {
        ChainsTypesSyncService(
            url: URL(string: "https://unused.invalid/types.json"),
            dataOperationFactory: factory,
            operationQueue: queue,
            retryStrategy: NoRetry()
        )
    }
}

private final class TypesFactory: NetworkOperationFactoryProtocol {
    private let make: () -> BaseOperation<JSON>
    private(set) var requests = 0

    init(_ make: @escaping () -> BaseOperation<JSON>) {
        self.make = make
    }

    func fetchData<T: Decodable>(from _: URL) -> BaseOperation<T> {
        requests += 1
        return make() as! BaseOperation<T>
    }
}
