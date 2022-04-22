import Foundation
import RobinHood
import SoraKeystore

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    private let priceId: AssetModel.PriceId?
    private var settings: SettingsManagerProtocol {
        SettingsManager.shared
    }

    init(assetId: WalletAssetId) {
        priceId = assetId.coingeckoTokenId
    }

    init(priceId: AssetModel.PriceId) {
        self.priceId = priceId
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if let priceId = priceId {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(
                for: [priceId],
                currency: settings.selectedCurrency
            )

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
