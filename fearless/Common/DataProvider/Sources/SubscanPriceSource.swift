import Foundation
import RobinHood

final class SubscanPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    let assetId: WalletAssetId

    init(assetId: WalletAssetId) {
        self.assetId = assetId
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if assetId.hasPrice, let baseUrl = assetId.subscanUrl {
            let url = baseUrl.appendingPathComponent(SubscanApi.price)
            let time = Int64(Date().timeIntervalSince1970)
            let priceOperation = SubscanOperationFactory().fetchPriceOperation(url, time: time)

            let targetOperation: BaseOperation<PriceData?> = ClosureOperation {
                try priceOperation.extractNoCancellableResultData()
            }

            targetOperation.addDependency(priceOperation)

            return CompoundOperationWrapper(targetOperation: targetOperation,
                                            dependencies: [priceOperation])
        } else {
            return  CompoundOperationWrapper.createWithResult(nil)
        }
    }
}
