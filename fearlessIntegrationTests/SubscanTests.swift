import XCTest
import IrohaCrypto
import RobinHood
import BigInt
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

    func testTotalRewardFetch() throws {
        do {
            // given

            guard let url = WalletAssetId.dot.subscanUrl?
                    .appendingPathComponent(SubscanApi.rewardAndSlash) else {
                XCTFail("unexpected empty url")
                return
            }

            let subscan = SubscanOperationFactory()
            let pageLength = 100
            let precision: Int16 = SNAddressType.polkadotMain.precision

            let address = "16ck3L2PCiMqxkThryw8tQ1T9oPQJxo6XZgkd4XKkdyU8zUL"

            let operationQueue = OperationQueue()

            // when

            let firstPageRequest = RewardInfo(address: address,
                                              row: pageLength,
                                              page: 0)

            let firstPageOperation = subscan.fetchRewardsAndSlashesOperation(url, info: firstPageRequest)

            operationQueue.addOperations([firstPageOperation], waitUntilFinished: true)

            let firstPage = try firstPageOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            let otherPageOperations: [BaseOperation<SubscanRewardData>]

            if firstPage.count > pageLength {
                let remainedItemsCount = firstPage.count - pageLength
                let remainedPagesCount = remainedItemsCount % pageLength == 0 ? remainedItemsCount / pageLength
                    : (remainedItemsCount / pageLength) + 1

                otherPageOperations = (0..<remainedPagesCount).map { pageIndex in
                    let info = RewardInfo(address: address, row: pageLength, page: pageIndex + 1)
                    return subscan.fetchRewardsAndSlashesOperation(url, info: info)
                }
            } else {
                otherPageOperations = []
            }

            let allPagesOperations = [firstPageOperation] + otherPageOperations

            let totalRewardOperation = ClosureOperation<Decimal> {
                let totalReward = try allPagesOperations.flatMap { operation in
                    try operation
                        .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                        .items
                }.reduce(BigUInt(0)) { (total, item) in
                    guard let amount = BigUInt(item.amount) else {
                        return total
                    }

                    return total + amount
                }

                return Decimal.fromSubstrateAmount(totalReward, precision: precision) ?? 0.0
            }

            for otherOperation in otherPageOperations {
                totalRewardOperation.addDependency(otherOperation)
            }

            operationQueue.addOperations(otherPageOperations + [totalRewardOperation],
                                         waitUntilFinished: true)

            // then

            let totalReward = try totalRewardOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            Logger.shared.debug("Total items count: \(firstPage.count)")
            Logger.shared.debug("Total operations: \(otherPageOperations.count + 1)")
            Logger.shared.debug("Total reward: \(totalReward)")
        } catch {
            if let subscanError = error as? SubscanError {
                XCTFail("Subscan error: \(subscanError.message) \(subscanError.code)")
            } else {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
}
