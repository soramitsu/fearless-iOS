import Foundation
import RobinHood

extension WalletNetworkFacade {
    func fetchPriceOperation(_ asset: WalletAssetId) -> CompoundOperationWrapper<Price?> {
        guard
            asset.hasPrice
        else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        let priceOperation = coingeckoOperationFactory.fetchPriceOperation(for: [asset])

        let mappingOperation: BaseOperation<Price?> = ClosureOperation {
            let priceData = try? priceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .first

            return Price(
                assetId: asset,
                lastValue: Decimal(string: priceData?.price ?? "") ?? 0.0,
                change: (priceData?.usdDayChange ?? 0.0) / 100.0
            )
        }

        mappingOperation.addDependency(priceOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [priceOperation]
        )
    }
}
