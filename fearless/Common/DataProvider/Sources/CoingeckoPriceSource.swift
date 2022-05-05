import Foundation
import RobinHood
import SoraKeystore

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    private let priceId: AssetModel.PriceId?
    private lazy var currency: Currency? = {
        SelectedWalletSettings.shared.value?.selectedCurrency
    }()

    private let eventCentr: EventCenterProtocol = {
        EventCenter.shared
    }()

    init(assetId: WalletAssetId) {
        priceId = assetId.coingeckoTokenId
        setup()
    }

    init(priceId: AssetModel.PriceId) {
        self.priceId = priceId
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if let priceId = priceId, let currency = currency {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(
                for: [priceId],
                currency: currency
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

    private func setup() {
        eventCentr.add(observer: self)
    }
}

extension CoingeckoPriceSource: EventVisitorProtocol {
    func processAssetsListChanged(event: AssetsListChangedEvent) {
        currency = event.account.selectedCurrency
    }
}
