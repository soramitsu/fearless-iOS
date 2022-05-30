import Foundation
import RobinHood
import SoraKeystore

final class CoingeckoPricesSource: SingleValueProviderSourceProtocol {
    typealias Model = [PriceData]

    private let pricesIds: [AssetModel.PriceId]
    private lazy var currency: Currency? = {
        SelectedWalletSettings.shared.value?.selectedCurrency
    }()

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    init(pricesIds: [AssetModel.PriceId]) {
        self.pricesIds = pricesIds
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<[PriceData]?> {
        if let currency = currency {
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
