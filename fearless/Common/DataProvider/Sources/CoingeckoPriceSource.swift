import Foundation
import RobinHood

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = CoingeckoPriceData

    let assetId: WalletAssetId

    init(assetId: WalletAssetId) {
        self.assetId = assetId
    }

    func fetchOperation() -> CompoundOperationWrapper<CoingeckoPriceData?> {
        if assetId.hasPrice {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(for: [assetId])

            let targetOperation: BaseOperation<CoingeckoPriceData?> = ClosureOperation {
                try priceOperation.extractNoCancellableResultData()
            }

            targetOperation.addDependency(priceOperation)

            return CompoundOperationWrapper(
                targetOperation: targetOperation,
                dependencies: [priceOperation]
            )
        } else {
            return CompoundOperationWrapper.createWithResult(nil)
        }
    }
}
