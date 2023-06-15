import Foundation
import RobinHood
import SoraKeystore
import SSFModels

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    private let priceId: AssetModel.PriceId?
    private var currency: Currency?

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    init(assetId: WalletAssetId) {
        priceId = assetId.coingeckoTokenId
        setup()
    }

    init(priceId: AssetModel.PriceId, currency: Currency?) {
        self.priceId = priceId
        self.currency = currency
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        if let priceId = priceId,
           let currency = self.currency ?? SelectedWalletSettings.shared.value?.selectedCurrency {
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
        eventCenter.add(observer: self)
    }
}

extension CoingeckoPriceSource: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        currency = event.account.selectedCurrency
    }
}
