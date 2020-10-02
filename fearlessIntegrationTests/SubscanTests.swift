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
}
