import Foundation
import sorawallet
import RobinHood
import SoraKeystore
import SSFModels

enum PriceDataSourceError: Swift.Error {
    case memoryError
}

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
        let soraSubqueryOperations = createSoraSubqueryOperation()

        let targetOperation: BaseOperation<[PriceData]?> = ClosureOperation { [weak self] in
            guard let self else {
                throw PriceDataSourceError.memoryError
            }

            var prices: [PriceData] = []
            let coingeckoPrices = try coingeckoOperation.extractNoCancellableResultData()
            let chainlinkPrices = chainlinkOperations.compactMap {
                try? $0.extractNoCancellableResultData()
            }
            let soraSubqueryPrices = soraSubqueryOperations.compactMap {
                try? $0.extractNoCancellableResultData()
            }.reduce([], +)

            prices = self.merge(coingeckoPrices: coingeckoPrices, chainlinkPrices: chainlinkPrices)
            prices = self.merge(coingeckoPrices: prices, soraSubqueryPrices: soraSubqueryPrices)

            return prices
        }

        soraSubqueryOperations.forEach {
            targetOperation.addDependency($0)
        }
        targetOperation.addDependency(coingeckoOperation)
        chainlinkOperations.forEach {
            targetOperation.addDependency($0)
        }

        return CompoundOperationWrapper(
            targetOperation: targetOperation,
            dependencies: [coingeckoOperation] + chainlinkOperations + soraSubqueryOperations
        )
    }

    // MARK: - Private methods

    private func merge(coingeckoPrices: [PriceData], chainlinkPrices: [PriceData]) -> [PriceData] {
        let caPriceIds = Set(chainAssets.compactMap { $0.asset.coingeckoPriceId })
        let sqPriceIds = Set(chainlinkPrices.compactMap { $0.coingeckoPriceId })

        let replacedFiatDayChange: [PriceData] = chainlinkPrices.compactMap { chainlinkPrice in
            let coingeckoPrice = coingeckoPrices.first(where: { $0.coingeckoPriceId == chainlinkPrice.coingeckoPriceId })
            return chainlinkPrice.replaceFiatDayChange(fiatDayChange: coingeckoPrice?.fiatDayChange)
        }

        let filtered = coingeckoPrices.filter { coingeckoPrice in
            guard let coingeckoPriceId = coingeckoPrice.coingeckoPriceId else {
                return true
            }
            return !caPriceIds.intersection(sqPriceIds).contains(coingeckoPriceId)
        }

        return filtered + replacedFiatDayChange
    }

    private func merge(coingeckoPrices: [PriceData], soraSubqueryPrices: [PriceData]) -> [PriceData] {
        let caPriceIds = Set(chainAssets.compactMap { $0.asset.priceId })
        let sqPriceIds = Set(soraSubqueryPrices.compactMap { $0.priceId })

        let replacedFiatDayChange: [PriceData] = soraSubqueryPrices.compactMap { soraSubqueryPrice in
            let coingeckoPrice = coingeckoPrices.first(where: { $0.priceId == soraSubqueryPrice.priceId })
            return soraSubqueryPrice.replaceFiatDayChange(fiatDayChange: coingeckoPrice?.fiatDayChange)
        }

        let filtered = coingeckoPrices.filter { coingeckoPrice in
            let chainAsset = chainAssets.first { $0.asset.coingeckoPriceId == coingeckoPrice.priceId }
            guard let priceId = chainAsset?.asset.priceId else {
                return true
            }
            return !caPriceIds.intersection(sqPriceIds).contains(priceId)
        }

        return filtered + replacedFiatDayChange
    }

    private func createSoraSubqueryOperation() -> [BaseOperation<[PriceData]>] {
        guard currencies?.count == 1, currencies?.first?.id == Currency.defaultCurrency().id else {
            return [BaseOperation.createWithResult([])]
        }

        let chains = chainAssets.filter { $0.asset.priceProvider?.type == .sorasubquery }.compactMap { $0.chain }.withoutDuplicates()

        let operations: [BaseOperation<[PriceData]>] = chains.compactMap { chain in
            let fetcher = SoraSubqueryPriceFetcherDefault(chain: chain)
            return AwaitOperation {
                let priceIds = chain.assets.filter { $0.priceProvider?.type == .sorasubquery }.compactMap { $0.priceProvider?.id }
                let prices = try await fetcher.fetch(priceIds: priceIds)

                return prices.compactMap { price in
                    let chainAsset = self.chainAssets.filter { $0.chain.knownChainEquivalent == .soraMain }.first(where: { $0.asset.currencyId == price.id })

                    guard
                        let chainAsset = chainAsset,
                        chainAsset.asset.priceProvider?.type == .sorasubquery,
                        let priceId = chainAsset.asset.priceId
                    else {
                        return nil
                    }

                    return PriceData(
                        currencyId: "usd",
                        priceId: priceId,
                        price: "\(price.priceUsd.or("0"))",
                        fiatDayChange: price.priceChangeDay,
                        coingeckoPriceId: chainAsset.asset.coingeckoPriceId
                    )
                }
            }
        }

        return operations
    }

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
