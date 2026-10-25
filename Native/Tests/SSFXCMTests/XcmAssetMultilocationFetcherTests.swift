import RobinHood
import SSFNetwork
import SSFUtils
import XCTest

@testable import SSFXCM

typealias OperationType = [RemoteAssetMultilocation]
typealias LocationsFactory = FreshOperationFactory<[RemoteAssetMultilocation]>

final class XcmAssetMultilocationFetcherTests: XCTestCase {
    func testInitLoadsNothing() async throws {
        // arrange
        let factory = LocationsFactory { ClosureOperation { [TestData.remote] } }

        // act: building the fetcher used to start a network task right away
        let fetcher = makeFetcher(factory: factory)
        try await Task.sleep(nanoseconds: 100_000_000)

        // assert
        XCTAssertNotNil(fetcher)
        XCTAssertEqual(factory.requestCount, 0)
    }

    func testVersionedMultilocation() async throws {
        // arrange
        let fetcher = makeFetcher(factory: LocationsFactory {
            ClosureOperation { [TestData.remote] }
        })

        // act
        let assetMultiplication = try await fetcher.versionedMultilocation(
            originAssetId: TestData.multilocation.id,
            destChainId: TestData.remote.chainId
        )

        // assert
        XCTAssertEqual(assetMultiplication, TestData.multilocation)
    }

    func testTheFileIsLoadedOnceAndKept() async throws {
        let factory = LocationsFactory { ClosureOperation { [TestData.remote] } }
        let fetcher = makeFetcher(factory: factory)

        for _ in 0 ..< 3 {
            _ = try await fetcher.versionedMultilocation(
                originAssetId: TestData.multilocation.id,
                destChainId: TestData.remote.chainId
            )
        }

        XCTAssertEqual(factory.requestCount, 1)
    }

    func testConcurrentCallersShareOneLoad() async throws {
        let factory = LocationsFactory {
            ClosureOperation {
                Thread.sleep(forTimeInterval: 0.05)
                return [TestData.remote]
            }
        }
        let fetcher = makeFetcher(factory: factory)

        let locations = try await withThrowingTaskGroup(of: AssetMultilocation.self) { group in
            for _ in 0 ..< 20 {
                group.addTask {
                    try await fetcher.versionedMultilocation(
                        originAssetId: TestData.multilocation.id,
                        destChainId: TestData.remote.chainId
                    )
                }
            }
            return try await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(locations, Array(repeating: TestData.multilocation, count: 20))
        XCTAssertEqual(factory.requestCount, 1)
    }

    func testVersionedMultilocationWithAssetError() async throws {
        // arrange
        let fetcher = makeFetcher(factory: LocationsFactory {
            ClosureOperation { [TestData.remote] }
        })

        // act
        do {
            _ = try await fetcher.versionedMultilocation(originAssetId: "1", destChainId: "2")
            XCTFail("Expected the unknown asset to be refused")
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingAssetLocationsResult.localizedDescription
            )
        }
    }

    func testAFailedLoadIsTriedUpToTheBoundThenReported() async throws {
        // arrange
        let factory = LocationsFactory {
            ClosureOperation { throw XcmError.missingLocalAssetLocations }
        }
        let fetcher = makeFetcher(
            factory: factory,
            retryStrategy: ExponentialReconnection(multiplier: 0.001, maxAttempts: 3)
        )

        // act
        do {
            _ = try await fetcher.versionedMultilocation(originAssetId: "1", destChainId: "2")
            XCTFail("Expected the failed request to be reported")
        } catch {
            // assert
            XCTAssertEqual(
                error.localizedDescription,
                XcmError.missingLocalAssetLocations.localizedDescription
            )
        }
        XCTAssertEqual(factory.requestCount, 3)
    }

    func testTheNextCallLoadsAgainAfterAFailure() async throws {
        // arrange: the first request fails, the second succeeds
        let factory = LocationsFactory(numbered: { request in
            ClosureOperation {
                if request == 1 {
                    throw XcmError.missingLocalAssetLocations
                }
                return [TestData.remote]
            }
        })
        let fetcher = makeFetcher(factory: factory)

        // act
        do {
            _ = try await fetcher.versionedMultilocation(
                originAssetId: TestData.multilocation.id,
                destChainId: TestData.remote.chainId
            )
            XCTFail("Expected the first load to fail")
        } catch {}
        let location = try await fetcher.versionedMultilocation(
            originAssetId: TestData.multilocation.id,
            destChainId: TestData.remote.chainId
        )

        // assert
        XCTAssertEqual(location, TestData.multilocation)
        XCTAssertEqual(factory.requestCount, 2)
    }

    func testLocationIsDeliveredWhenTheOperationFinishesAsItIsQueued() {
        // arrange: every request gets an operation that is done the moment it is queued. The
        // completion block used to be set after queueing, so such an operation never reported
        // back and the caller waited forever.
        let fetcher = makeFetcher(
            factory: LocationsFactory { ClosureOperation { [TestData.remote] } },
            operationQueue: ImmediateOperationQueue()
        )
        let location = AsyncResult<AssetMultilocation?>(expectation(description: "location"))

        // act
        Task {
            location.store(try? await fetcher.versionedMultilocation(
                originAssetId: TestData.multilocation.id,
                destChainId: TestData.remote.chainId
            ))
        }

        // assert
        wait(for: [location.completed], timeout: 5)
        XCTAssertEqual(location.value ?? nil, TestData.multilocation)
    }

    private func makeFetcher(
        factory: NetworkOperationFactoryProtocol,
        retryStrategy: ReconnectionStrategyProtocol = ReconnectionStrategyProtocolMock(),
        operationQueue: OperationQueue = OperationQueue()
    ) -> XcmAssetMultilocationFetching {
        XcmAssetMultilocationFetcher(
            sourceUrl: XcmConfig.shared.tokenLocationsSourceUrl,
            dataFetchFactory: factory,
            retryStrategy: retryStrategy,
            operationQueue: operationQueue
        )
    }
}

extension XcmAssetMultilocationFetcherTests {
    enum TestData {
        static let multilocation = AssetMultilocation(
            id: "0",
            symbol: "1",
            interiors: [.onlyChild]
        )

        static let remote = RemoteAssetMultilocation(
            name: "2",
            chainId: "3",
            assets: [multilocation]
        )
    }
}

/// Hands out a new operation for every request, unlike the generated mock that returns one
/// instance, which can only be queued once. Requests are numbered from 1.
final class FreshOperationFactory<Output: Decodable>: NetworkOperationFactoryProtocol {
    private let makeOperation: (Int) -> BaseOperation<Output>
    private let lock = NSLock()
    private var requests = 0

    var requestCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    init(numbered makeOperation: @escaping (Int) -> BaseOperation<Output>) {
        self.makeOperation = makeOperation
    }

    convenience init(makeOperation: @escaping () -> BaseOperation<Output>) {
        self.init(numbered: { _ in makeOperation() })
    }

    func fetchData<T: Decodable>(from _: URL) -> BaseOperation<T> {
        lock.lock()
        requests += 1
        let request = requests
        lock.unlock()

        guard let operation = makeOperation(request) as? BaseOperation<T> else {
            fatalError("Unexpected response type \(T.self)")
        }

        return operation
    }
}
