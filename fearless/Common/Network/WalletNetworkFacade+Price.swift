import Foundation
import RobinHood

extension WalletNetworkFacade {
    func fetchPriceOperation(_ asset: WalletAssetId) -> CompoundOperationWrapper<Price?> {
        guard
            asset.hasPrice,
            let url = asset.subscanUrl?.appendingPathComponent(SubscanApi.price) else {
            let operation = BaseOperation<Price?>()
            operation.result = .success(nil)
            return CompoundOperationWrapper(targetOperation: operation)
        }

        // calculating 24h difference in price

        let currentTime = Int64(Date().timeIntervalSince1970)
        let prevTime = currentTime - 24 * 3600
        let currentPriceOperation = subscanOperationFactory.fetchPriceOperation(url, time: currentTime)
        let prevPriceOperation = subscanOperationFactory.fetchPriceOperation(url, time: prevTime)

        let diffOperation: BaseOperation<Price?> = ClosureOperation {
            let currentPrice = try currentPriceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
            let prevPrice = try prevPriceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)

            // if no last price then also no change

            guard let currentPriceString = currentPrice.records
                .first(where: { $0.time <= currentTime})?.price else {
                return Price(assetId: asset, lastValue: .zero, change: .zero)
            }

            guard let currentPriceValue = Decimal(string: currentPriceString) else {
                throw NetworkBaseError.unexpectedResponseObject
            }

            let prevPriceValue: Decimal

            // if no prev price then assuming it was zero

            if let prevPriceString = prevPrice.records.first(where: { $0.time <= prevTime })?.price {
                guard let value = Decimal(string: prevPriceString) else {
                    throw NetworkBaseError.unexpectedResponseObject
                }

                prevPriceValue = value
            } else {
                prevPriceValue = .zero
            }

            // if prev price was zero then change is 100%

            guard prevPriceValue > .zero else {
                return Price(assetId: asset, lastValue: currentPriceValue, change: 1.0)
            }

            // calculating change in price in percentage

            let change = ((currentPriceValue - prevPriceValue) / prevPriceValue)

            return Price(assetId: asset, lastValue: currentPriceValue, change: change)
        }

        diffOperation.addDependency(currentPriceOperation)
        diffOperation.addDependency(prevPriceOperation)

        return CompoundOperationWrapper(targetOperation: diffOperation,
                                        dependencies: [prevPriceOperation, currentPriceOperation])
    }
}
