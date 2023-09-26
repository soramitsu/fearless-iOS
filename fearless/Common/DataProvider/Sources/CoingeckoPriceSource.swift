import Foundation
import RobinHood
import SoraKeystore
import SSFModels

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    private let priceId: AssetModel.PriceId?
    private var currencies: [Currency]?

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    init(assetId: WalletAssetId) {
        priceId = assetId.coingeckoTokenId
        setup()
    }

    init(priceId: AssetModel.PriceId, currencies: [Currency]?) {
        self.priceId = priceId
        self.currencies = currencies
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        let currencies = self.currencies ?? [SelectedWalletSettings.shared.value?.selectedCurrency].compactMap { $0 }
        if let priceId = priceId, currencies.isNotEmpty {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(
                for: [priceId],
                currencies: currencies.compactMap { $0 }
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
        currencies = [event.account.selectedCurrency]
    }
}
