import Foundation
import RobinHood

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    let assetId: WalletAssetId

    init(assetId: WalletAssetId) {
        self.assetId = assetId
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if let tokenId = assetId.coingeckoTokenId {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(for: [tokenId])

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
