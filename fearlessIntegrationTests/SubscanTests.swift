import XCTest
import IrohaCrypto
import RobinHood
@testable import fearless

class SubscanTests: XCTestCase {
    func testFetchPriceDifference() throws {
        do {
            guard let url = WalletAssetId.kusama.subscanUrl?
                .appendingPathComponent(SubscanApi.price) else {
                XCTFail("unexpected empty url")
                return
            }

            let subscan = SubscanOperationFactory()
            let currentTime = Int64(Date().timeIntervalSince1970)
            let prevTime = currentTime - 24 * 3600
            let currentPriceOperation = subscan.fetchPriceOperation(url, time: currentTime)
            let prevPriceOperation = subscan.fetchPriceOperation(url, time: prevTime)

            let diffOperation: BaseOperation<Decimal> = ClosureOperation {
                let currentPrice = try currentPriceOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                let prevPrice = try prevPriceOperation
                    .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

                guard let currentPriceString = currentPrice.records
                    .first(where: { $0.time <= currentTime})?.price else {
                    return Decimal.zero
                }

                guard let currentPriceValue = Decimal(string: currentPriceString) else {
                    throw NetworkBaseError.unexpectedResponseObject
                }

                let prevPriceValue: Decimal

                if let prevPriceString = prevPrice.records.first(where: { $0.time <= prevTime} )?.price {
                    guard let value = Decimal(string: prevPriceString) else {
                        throw NetworkBaseError.unexpectedResponseObject
                    }

                    prevPriceValue = value
                } else {
                    prevPriceValue = .zero
                }

                guard prevPriceValue > .zero else {
                    return 100
                }

                return ((currentPriceValue - prevPriceValue) / prevPriceValue) * 100.0
            }

            diffOperation.addDependency(currentPriceOperation)
            diffOperation.addDependency(prevPriceOperation)

            OperationQueue().addOperations([currentPriceOperation, prevPriceOperation, diffOperation],
                                           waitUntilFinished: true)

            let result = try diffOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            Logger.shared.debug("Did receive result: \(result)")
        } catch {
            XCTFail("Did receive error \(error)")
        }
    }

    func testSingleRequest() throws {
        try fetchPrice(requests: 1)
    }

    func testMultipleRequests() throws {
        try fetchPrice(requests: 10)
    }

    func testPolkadotRewardFetch() {
        measure {
            performRewardTest(for: "15cfSaBcTxNr8rV59cbhdMNCRagFr3GE6B3zZRsCp4QHHKPu",
                              assetId: .dot)
        }
    }

    func testKusamaRewardFetch() {
        measure {
            performRewardTest(for: "Day71GSJAxUUiFic8bVaWoAczR3Ue3jNonBZthVHp2BKzyJ",
                              assetId: .kusama)
        }
    }

    func testWestendRewardFetch() {
        measure {
            performRewardTest(for: "5CDayXd3cDCWpBkSXVsVfhE5bWKyTZdD3D1XUinR1ezS1sGn",
                              assetId: .westend)
        }
    }

    private func performRewardTest(for address: String, assetId: WalletAssetId) {
        do {
            let storageFacade = SubstrateStorageTestFacade()
            let operationManager = OperationManager()
            let logger = Logger.shared

            let singleValueProviderFactory = SingleValueProviderFactory(facade: storageFacade,
                                                                        operationManager: operationManager,
                                                                        logger: logger)

            let provider = try singleValueProviderFactory.getTotalReward(for: address, assetId: assetId)

            let expectation = XCTestExpectation()

            var totalReward: TotalRewardItem? = nil

            let changesClosure = { (changes: [DataProviderChange<TotalRewardItem>]) -> Void in
                totalReward = changes.reduceToLastChange()

                if totalReward != nil {
                    expectation.fulfill()
                }
            }

            let failureClosure = { (error: Error) -> Void in
                XCTFail("Unexpected error: \(error)")

                expectation.fulfill()
            }

            let options = DataProviderObserverOptions(alwaysNotifyOnRefresh: true,
                                                      waitsInProgressSyncOnAdd: false)

            provider.addObserver(self,
                                 deliverOn: .main,
                                 executing: changesClosure,
                                 failing: failureClosure,
                                 options: options)

            wait(for: [expectation], timeout: 100.0)

            if let receivedReward = totalReward {
                logger.debug("Did receive reward: \(receivedReward.amount.stringValue)")
            } else {
                logger.debug("No reward found")
            }

            let fetchExpectation = XCTestExpectation()

            _ = provider.fetch { result in
                switch result {
                case .success(let resultReward):
                    XCTAssertEqual(resultReward, totalReward)
                case .failure(let error):
                    XCTFail("Unexpected error: \(error)")
                case .none:
                    XCTFail("Unexpected nil")
                }

                fetchExpectation.fulfill()
            }

            wait(for: [fetchExpectation], timeout: 100.0)

        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func fetchPrice(requests: Int) throws {
        guard let url = WalletAssetId.kusama.subscanUrl?
                .appendingPathComponent(SubscanApi.price) else {
            XCTFail("unexpected empty url")
            return
        }

        let subscan = SubscanOperationFactory()

        var operations: [BaseOperation<PriceData>] = []

        for _ in 0..<requests {
            let currentTime = Int64(Date().timeIntervalSince1970)
            let priceOperation = subscan.fetchPriceOperation(url, time: currentTime)
            priceOperation.completionBlock = {
                do {
                    let result = try priceOperation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                    Logger.shared.debug("Did receive result: \(result)")
                } catch {
                    XCTFail("Did receive error \(error)")
                }
            }
            operations.append(priceOperation)
        }

        OperationQueue().addOperations(operations, waitUntilFinished: true)
    }
}
