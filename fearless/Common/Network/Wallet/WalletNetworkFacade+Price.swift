import Foundation
import RobinHood

extension WalletNetworkFacade {
    func fetchPriceOperation(_ asset: WalletAssetId, currency: Currency) -> CompoundOperationWrapper<Price?> {
        guard let tokenId = asset.coingeckoTokenId else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        let priceOperation = coingeckoOperationFactory.fetchPriceOperation(
            for: [tokenId],
            currency: currency
        )

        let mappingOperation: BaseOperation<Price?> = ClosureOperation {
            let priceData = try? priceOperation
                .extractResultData(throwing: BaseOperationError.parentOperationCancelled)
                .first

            return Price(
                assetId: asset,
                lastValue: Decimal(string: priceData?.price ?? "") ?? 0.0,
                change: (priceData?.fiatDayChange ?? 0.0) / 100.0
            )
        }

        mappingOperation.addDependency(priceOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [priceOperation]
        )
    }
}
