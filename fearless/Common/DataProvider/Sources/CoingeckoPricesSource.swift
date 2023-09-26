import Foundation
import RobinHood
import SoraKeystore
import SSFModels

final class CoingeckoPricesSource: SingleValueProviderSourceProtocol {
    typealias Model = [PriceData]

    private let pricesIds: [AssetModel.PriceId]
    private var currencies: [Currency]?

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    private let readWriterLock = ReaderWriterLock()

    init(pricesIds: [AssetModel.PriceId], currencies: [Currency]? = nil) {
        self.pricesIds = pricesIds
        self.currencies = currencies
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<[PriceData]?> {
        let currencies = readWriterLock.concurrentlyRead {
            self.currencies ?? [SelectedWalletSettings.shared.value?.selectedCurrency].compactMap { $0 }
        }

        if currencies.isNotEmpty {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(
                for: pricesIds,
                currencies: currencies.compactMap { $0 }
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
        readWriterLock.exclusivelyWrite { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.currencies != [event.account.selectedCurrency] {
                strongSelf.currencies = [event.account.selectedCurrency]
            }
        }
    }
}
