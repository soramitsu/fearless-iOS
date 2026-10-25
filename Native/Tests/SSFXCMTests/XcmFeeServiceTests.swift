import BigInt
import RobinHood
import SSFModels
import SSFUtils
import XCTest

@testable import SSFXCM

final class XcmFeeServiceTests: XCTestCase {
    var service: XcmDestinationFeeFetching?
    var factory: NetworkOperationFactoryProtocolMock<[XcmFee]>?

    override func setUp() {
        super.setUp()

        let factory = NetworkOperationFactoryProtocolMock<[XcmFee]>()
        factory.fetchDataFromReturnValue = createOperation()
        self.factory = factory

        service = XcmDestinationFeeFetcher(
            sourceUrl: XcmConfig.shared.chainsSourceUrl,
            networkOperationFactory: factory,
            operationQueue: OperationQueue()
        )
    }

    override func tearDown() {
        super.tearDown()
        factory = nil
        service = nil
    }

    func testEstimateFee() async {
        // arrange
        let destinationChainId = "0"
        let token = "xc0"

        // act
        let result = await service?.estimateFee(
            destinationChainId: destinationChainId,
            token: token
        )

        // assert
        XCTAssertNotNil(result)

        switch result {
        case let .success(destXcmFee):
            XCTAssertEqual(destXcmFee, TestData.destXcmFee)
        case let .failure(error):
            XCTFail(error.localizedDescription)
        case .none:
            XCTFail()
        }
    }

    func testTheFeeFileIsFetchedOnceWithTheCache() async throws {
        // `fees` was never assigned, so every quote fetched the file again.
        let factory = FreshOperationFactory<[XcmFee]> { ClosureOperation { [TestData.xcmFee] } }
        let service = XcmDestinationFeeFetcher(
            sourceUrl: XcmConfig.shared.destinationFeeSourceUrl,
            networkOperationFactory: factory,
            operationQueue: OperationQueue()
        )

        for _ in 0 ..< 3 {
            let fee = try await service.estimateFee(destinationChainId: "0", token: "0").get()
            XCTAssertEqual(fee, TestData.destXcmFee)
        }

        XCTAssertEqual(factory.requestCount, 1)
    }

    func testWithoutTheCacheEveryQuoteFetchesTheFile() async throws {
        let factory = FreshOperationFactory<[XcmFee]> { ClosureOperation { [TestData.xcmFee] } }
        let service = XcmDestinationFeeFetcher(
            sourceUrl: XcmConfig.shared.destinationFeeSourceUrl,
            networkOperationFactory: factory,
            operationQueue: OperationQueue(),
            useCache: false
        )

        for _ in 0 ..< 2 {
            _ = try await service.estimateFee(destinationChainId: "0", token: "0").get()
        }

        XCTAssertEqual(factory.requestCount, 2)
    }

    func testAFailedFetchIsNotCached() async throws {
        let factory = FreshOperationFactory<[XcmFee]>(numbered: { request in
            ClosureOperation {
                if request == 1 {
                    throw XcmError.missingRemoteFeeResult
                }
                return [TestData.xcmFee]
            }
        })
        let service = XcmDestinationFeeFetcher(
            sourceUrl: XcmConfig.shared.destinationFeeSourceUrl,
            networkOperationFactory: factory,
            operationQueue: OperationQueue()
        )

        let first = await service.estimateFee(destinationChainId: "0", token: "0")
        let second = await service.estimateFee(destinationChainId: "0", token: "0")

        XCTAssertThrowsError(try first.get())
        XCTAssertEqual(try second.get(), TestData.destXcmFee)
        XCTAssertEqual(factory.requestCount, 2)
    }
}

extension XcmFeeServiceTests {
    func testEstimateFeeResumesWhenTheOperationFinishesAsItIsQueued() throws {
        // arrange: the completion block used to be set after the operation was queued, so an
        // operation that finished first never reported back and the caller waited forever
        let service = try XCTUnwrap(makeService(on: ImmediateOperationQueue()))
        let fee = AsyncResult<DestXcmFee?>(expectation(description: "estimateFee"))

        Task {
            let result = await service.estimateFee(destinationChainId: "0", token: "0")
            fee.store(try? result.get())
        }

        wait(for: [fee.completed], timeout: 5)
        XCTAssertEqual(fee.value ?? nil, TestData.destXcmFee)
    }

    private func makeService(on queue: OperationQueue) -> XcmDestinationFeeFetching? {
        guard let factory = factory else { return nil }

        return XcmDestinationFeeFetcher(
            sourceUrl: XcmConfig.shared.chainsSourceUrl,
            networkOperationFactory: factory,
            operationQueue: queue
        )
    }
}

private extension XcmFeeServiceTests {
    private enum TestData {
        static let destXcmFee = DestXcmFee(
            feeInPlanks: BigUInt(),
            symbol: "0",
            precision: "0"
        )

        static let xcmFee = XcmFee(
            chainId: "0",
            destChain: "0",
            destXcmFee: [.init(
                feeInPlanks: BigUInt(),
                symbol: "0",
                precision: "0"
            )],
            weight: BigUInt()
        )
    }

    private func createOperation() -> BaseOperation<[XcmFee]> {
        let operation = ClosureOperation {
            [TestData.xcmFee]
        }

        return operation
    }
}
