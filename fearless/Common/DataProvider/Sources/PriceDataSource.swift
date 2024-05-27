import Foundation

import Foundation
import RobinHood
import SoraKeystore
import SSFModels

final class PriceDataSource: SingleValueProviderSourceProtocol {
    static let defaultIdentifier: String = "all-chainAsset-prices-usd"
    typealias Model = [PriceData]

    var identifier: String {
        currencies?.compactMap { $0.id }.joined(separator: ".") ?? Self.defaultIdentifier
    }

    private var currencies: [Currency]?

    private let eventCenter: EventCenterProtocol = {
        EventCenter.shared
    }()

    private lazy var coingeckoOperationFactory: CoingeckoOperationFactoryProtocol = {
        CoingeckoOperationFactory()
    }()

    private lazy var chainlinkOperationFactory: ChainlinkOperationFactory = {
        ChainlinkOperationFactoryImpl()
    }()

    private lazy var chainAssets: [ChainAsset] = {
        ChainRegistryFacade.sharedRegistry.availableChains.map { $0.chainAssets }.reduce([], +)
    }()

    init(currencies: [Currency]?) {
        self.currencies = currencies
        setup()
    }

    func fetchOperation() -> CompoundOperationWrapper<[PriceData]?> {
        let coingeckoOperation = createCoingeckoOperation()
        let chainlinkOperations = createChainlinkOperations()

        let targetOperation: BaseOperation<[PriceData]?> = ClosureOperation { [weak self] in
            var coingeckoPrices = try coingeckoOperation.extractNoCancellableResultData()
            let chainlinkPrices = chainlinkOperations.compactMap {
                try? $0.extractNoCancellableResultData()
            }

            let replacedFiatDayChange: [PriceData] = chainlinkPrices.compactMap { chainlinkPrice in
                let coingeckoPrice = coingeckoPrices.first(where: { $0.coingeckoPriceId == chainlinkPrice.coingeckoPriceId })
                return chainlinkPrice.replaceFiatDayChange(fiatDayChange: coingeckoPrice?.fiatDayChange)
            }

            if chainlinkPrices.count != chainlinkOperations.count || chainlinkOperations.isEmpty {
                let chainlinkPriceChainAsset = self?.chainAssets.filter { $0.asset.priceProvider?.type == .chainlink }
                let failedPriceId = chainlinkPriceChainAsset?.compactMap { $0.asset.coingeckoPriceId }.diff(from: chainlinkPrices.map { $0.coingeckoPriceId })
                let replacedPrices = coingeckoPrices.compactMap { price in
                    if failedPriceId?.contains(price.coingeckoPriceId) == true {
                        guard let failedChainlinkCHainAsset = chainlinkPriceChainAsset?.first(where: { $0.asset.coingeckoPriceId == price.coingeckoPriceId }) else {
                            return price
                        }
                        return PriceData(
                            currencyId: price.currencyId,
                            priceId: failedChainlinkCHainAsset.asset.priceProvider?.id ?? price.priceId,
                            price: price.price,
                            fiatDayChange: price.fiatDayChange,
                            coingeckoPriceId: price.coingeckoPriceId
                        )
                    }
                    return nil
                }
                coingeckoPrices = coingeckoPrices + replacedPrices
            }

            return coingeckoPrices + replacedFiatDayChange
        }

        targetOperation.addDependency(coingeckoOperation)
        chainlinkOperations.forEach {
            targetOperation.addDependency($0)
        }

        return CompoundOperationWrapper(
            targetOperation: targetOperation,
            dependencies: [coingeckoOperation] + chainlinkOperations
        )
    }

    // MARK: - Private methods

    private func createCoingeckoOperation() -> BaseOperation<[PriceData]> {
        let currencies = self.currencies ?? [SelectedWalletSettings.shared.value?.selectedCurrency].compactMap { $0 }
        let priceIds = chainAssets
            .map { $0.asset.coingeckoPriceId }
            .compactMap { $0 }
            .uniq(predicate: { $0 })
        let operation = coingeckoOperationFactory.fetchPriceOperation(for: priceIds, currencies: currencies)
        return operation
    }

    private func createChainlinkOperations() -> [BaseOperation<PriceData>] {
        guard currencies?.count == 1, currencies?.first?.id == Currency.defaultCurrency().id else {
            return []
        }
        let chainlinkPriceChainAsset = chainAssets
            .filter { $0.asset.priceProvider?.type == .chainlink }

        let operations = chainlinkPriceChainAsset
            .map { chainlinkOperationFactory.priceCall(for: $0) }
        return operations.compactMap { $0 }
    }

    private func setup() {
        eventCenter.add(observer: self)
    }
}

extension PriceDataSource: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        currencies = (currencies.or([]) + [event.account.selectedCurrency]).uniq(predicate: { $0.id })
    }
}
