import Foundation
import RobinHood

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    let priceId: AssetModel.PriceId?

    init(assetId: WalletAssetId) {
        priceId = assetId.coingeckoTokenId
    }

    init(priceId: AssetModel.PriceId) {
        self.priceId = priceId
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if let priceId = priceId {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(for: [priceId])

            let targetOperation: BaseOperation<PriceData?> = ClosureOperation {
                try priceOperation.extractNoCancellableResultData().first
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
