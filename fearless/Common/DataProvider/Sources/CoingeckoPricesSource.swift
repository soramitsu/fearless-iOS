import Foundation
import RobinHood
import SoraKeystore
import SSFModels

final class CoingeckoPricesSource: SingleValueProviderSourceProtocol {
    typealias Model = [PriceData]

    private let pricesIds: [AssetModel.PriceId]
    private var currency: Currency?

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    init(pricesIds: [AssetModel.PriceId], currency: Currency? = nil) {
        self.pricesIds = pricesIds
        self.currency = currency
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<[PriceData]?> {
        if let currency = self.currency ?? SelectedWalletSettings.shared.value?.selectedCurrency {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(
                for: pricesIds,
                currency: currency
            )

            let targetOperation: BaseOperation<[PriceData]?> = ClosureOperation {
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

    private func setup() {
        eventCenter.add(observer: self)
    }
}

extension CoingeckoPricesSource: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        currency = event.account.selectedCurrency
    }
}
