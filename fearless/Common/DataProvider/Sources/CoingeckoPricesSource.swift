import Foundation
import RobinHood
import SoraKeystore
import SSFModels

final class CoingeckoPricesSource: SingleValueProviderSourceProtocol {
    typealias Model = [PriceData]

    private let pricesIds: [AssetModel.PriceId]
    private var currencys: [Currency]?

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    private let readWriterLock = ReaderWriterLock()

    init(pricesIds: [AssetModel.PriceId], currencys: [Currency]? = nil) {
        self.pricesIds = pricesIds
        self.currencys = currencys
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<[PriceData]?> {
        let currencys = readWriterLock.concurrentlyRead {
            self.currencys ?? [SelectedWalletSettings.shared.value?.selectedCurrency].compactMap { $0 }
        }

        if currencys.isNotEmpty {
            let priceOperation = CoingeckoOperationFactory().fetchPriceOperation(
                for: pricesIds,
                currencys: currencys.compactMap { $0 }
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
        readWriterLock.exclusivelyWrite { [unowned self] in
            if self.currencys != [event.account.selectedCurrency] {
                self.currencys = [event.account.selectedCurrency]
            }
        }
    }
}
