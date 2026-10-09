import RobinHood
import SSFNetwork
import XCTest
@testable import fearless

final class FeatureToggleProviderTests: XCTestCase {
    func testNilNetworkConfigFallsBackAndFinishesFetchOperation() throws {
        let context = makeProvider(networkPayload: Data("null".utf8), suspendNetwork: true)
        let fetchOperation = context.provider.fetchConfigOperation()

        let config = try execute(fetchOperation, on: context.fetchQueue) {
            context.networkQueue.isSuspended = false
        }
        assertDefault(config)
    }

    func testMalformedNetworkConfigFallsBackAndFinishesFetchOperation() throws {
        let context = makeProvider(networkPayload: Data("{".utf8))
        let config = try execute(context.provider.fetchConfigOperation(), on: context.fetchQueue)

        assertDefault(config)
    }

    func testValidNetworkConfigIsDeliveredWithoutDefaultSubstitution() throws {
        let context = makeProvider(
            networkPayload: Data(
                #"{"pendulumCaseEnabled":true,"nftEnabled":false}"#.utf8
            )
        )
        let config = try execute(context.provider.fetchConfigOperation(), on: context.fetchQueue)

        XCTAssertEqual(config.pendulumCaseEnabled, true)
        XCTAssertEqual(config.nftEnabled, false)
    }

    func testConcurrentPendingFetchesAllResolveExactlyOnce() throws {
        let context = makeProvider(
            networkPayload: Data(
                #"{"pendulumCaseEnabled":true,"nftEnabled":false}"#.utf8
            ),
            suspendNetwork: true
        )
        let operations = (0 ..< 32).map { _ in context.provider.fetchConfigOperation() }
        let completion = expectation(description: "all fetches resolve")
        completion.expectedFulfillmentCount = operations.count
        completion.assertForOverFulfill = true

        operations.forEach { operation in
            operation.completionBlock = {
                completion.fulfill()
            }
            context.fetchQueue.addOperation(operation)
        }

        context.networkQueue.isSuspended = false
        wait(for: [completion], timeout: 3)

        for operation in operations {
            let config = try result(of: operation)
            XCTAssertEqual(config.pendulumCaseEnabled, true)
            XCTAssertEqual(config.nftEnabled, false)
        }
    }

    func testFetchCreatedBeforeProviderDeallocationReturnsDefault() throws {
        let networkQueue = OperationQueue()
        networkQueue.isSuspended = true
        var provider: FeatureToggleProvider? = FeatureToggleProvider(
            networkOperationFactory: JSONNetworkOperationFactoryStub(payload: Data("null".utf8)),
            operationQueue: networkQueue
        )
        let fetchOperation = try XCTUnwrap(provider).fetchConfigOperation()
        provider = nil

        let config = try execute(fetchOperation, on: OperationQueue())
        assertDefault(config)

        networkQueue.cancelAllOperations()
        networkQueue.isSuspended = false
    }

    private func makeProvider(
        networkPayload: Data,
        suspendNetwork: Bool = false
    ) -> ProviderContext {
        let networkQueue = OperationQueue()
        networkQueue.isSuspended = suspendNetwork
        let fetchQueue = OperationQueue()
        fetchQueue.maxConcurrentOperationCount = 8

        return ProviderContext(
            provider: FeatureToggleProvider(
                networkOperationFactory: JSONNetworkOperationFactoryStub(payload: networkPayload),
                operationQueue: networkQueue
            ),
            networkQueue: networkQueue,
            fetchQueue: fetchQueue
        )
    }

    private func execute(
        _ operation: BaseOperation<FeatureToggleConfig>,
        on queue: OperationQueue,
        beforeWait: () -> Void = {}
    ) throws -> FeatureToggleConfig {
        let completion = expectation(description: "feature toggle fetch completes")
        operation.completionBlock = {
            completion.fulfill()
        }
        queue.addOperation(operation)
        beforeWait()
        wait(for: [completion], timeout: 3)
        return try result(of: operation)
    }

    private func result(
        of operation: BaseOperation<FeatureToggleConfig>
    ) throws -> FeatureToggleConfig {
        switch operation.result {
        case let .success(config):
            return config
        case let .failure(error):
            throw error
        case .none:
            throw FeatureToggleProviderTestError.missingOperationResult
        }
    }

    private func assertDefault(
        _ config: FeatureToggleConfig,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(config.pendulumCaseEnabled, false, file: file, line: line)
        XCTAssertEqual(config.nftEnabled, true, file: file, line: line)
    }
}

private enum FeatureToggleProviderTestError: Error {
    case missingOperationResult
}

private struct ProviderContext {
    let provider: FeatureToggleProvider
    let networkQueue: OperationQueue
    let fetchQueue: OperationQueue
}

private final class JSONNetworkOperationFactoryStub: NetworkOperationFactoryProtocol {
    private let payload: Data

    init(payload: Data) {
        self.payload = payload
    }

    func fetchData<T: Decodable>(from _: URL) -> BaseOperation<T> {
        ClosureOperation {
            try JSONDecoder().decode(T.self, from: self.payload)
        }
    }
}
