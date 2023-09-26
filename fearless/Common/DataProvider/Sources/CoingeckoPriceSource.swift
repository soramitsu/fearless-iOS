import Foundation
import RobinHood
import SoraKeystore
import SSFModels

final class CoingeckoPriceSource: SingleValueProviderSourceProtocol {
    typealias Model = PriceData

    private let priceId: AssetModel.PriceId?
    private var currencys: [Currency]?

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    init(assetId: WalletAssetId) {
        priceId = assetId.coingeckoTokenId
        setup()
    }

    init(priceId: AssetModel.PriceId, currencys: [Currency]?) {
        self.priceId = priceId
        self.currencys = currencys
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<PriceData?> {
        let currencys = self.currencys ?? [SelectedWalletSettings.shared.value?.selectedCurrency].compactMap { $0 }
        if let priceId = priceId, currencys.isNotEmpty {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(
                for: [priceId],
                currencys: currencys.compactMap { $0 }
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
        currencys = [event.account.selectedCurrency]
    }
}
