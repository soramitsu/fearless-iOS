import Foundation
import RobinHood
import SoraKeystore
import SSFModels
import sorawallet

enum PriceDataSourceError: Swift.Error {
    case memoryError
    case inputDataMissed
}

protocol PriceDataCacheReading {
    func fetchPricesOperation() -> CompoundOperationWrapper<[PriceData]>
}

final class PriceDataCacheReader: PriceDataCacheReading {
    private let repository: AnyDataProviderRepository<SingleValueProviderObject>
    private let identifier: String

    init(
        repository: AnyDataProviderRepository<SingleValueProviderObject>,
        identifier: String
    ) {
        self.repository = repository
        self.identifier = identifier
    }

    func fetchPricesOperation() -> CompoundOperationWrapper<[PriceData]> {
        let repositoryOperation = repository.fetchOperation(
            by: identifier,
            options: RepositoryFetchOptions()
        )
        let targetOperation = ClosureOperation<[PriceData]> {
            guard
                let object = try repositoryOperation.extractNoCancellableResultData()
            else {
                return []
            }

            return (try? JSONDecoder().decode([PriceData].self, from: object.payload)) ?? []
        }
        targetOperation.addDependency(repositoryOperation)

        return CompoundOperationWrapper(
            targetOperation: targetOperation,
            dependencies: [repositoryOperation]
        )
    }
}

private struct EmptyPriceDataCacheReader: PriceDataCacheReading {
    func fetchPricesOperation() -> CompoundOperationWrapper<[PriceData]> {
        CompoundOperationWrapper.createWithResult([])
    }
}

final class PriceDataSource: SingleValueProviderSourceProtocol {
    private struct PriceKey: Hashable {
        let currencyId: String
        let priceId: String
    }

    private struct Context {
        var currencies: [Currency]?
        var chainAssets: [ChainAsset]
        var revision: UInt64
    }

    static let defaultIdentifier: String = "all-chainAsset-prices-usd"
    typealias Model = [PriceData]

    var identifier: String {
        contextSnapshot().currencies?.map(\.id).joined(separator: ".") ?? Self.defaultIdentifier
    }

    private let eventCenter: EventCenterProtocol
    private let coingeckoOperationFactory: CoingeckoOperationFactoryProtocol
    private let chainlinkOperationFactory: ChainlinkOperationFactory
    private let soraOperationFactory: SoraSubqueryPriceFetcher
    private let priceCacheReader: PriceDataCacheReading
    private let chainRegistry: ChainRegistryProtocol

    private let contextLock = NSLock()
    private var context: Context
    private var lastCompletedRevision: UInt64?

    init(
        currencies: [Currency]?,
        chainAssets: [ChainAsset],
        coingeckoOperationFactory: CoingeckoOperationFactoryProtocol = CoingeckoOperationFactory(),
        chainlinkOperationFactory: ChainlinkOperationFactory = ChainlinkOperationFactoryImpl(),
        soraOperationFactory: SoraSubqueryPriceFetcher = SoraSubqueryPriceFetcherDefault(),
        priceCacheReader: PriceDataCacheReading = EmptyPriceDataCacheReader(),
        chainRegistry: ChainRegistryProtocol = ChainRegistryFacade.sharedRegistry,
        eventCenter: EventCenterProtocol = EventCenter.shared
    ) {
        context = Context(
            currencies: currencies,
            chainAssets: chainAssets,
            revision: 0
        )
        self.coingeckoOperationFactory = coingeckoOperationFactory
        self.chainlinkOperationFactory = chainlinkOperationFactory
        self.soraOperationFactory = soraOperationFactory
        self.priceCacheReader = priceCacheReader
        self.chainRegistry = chainRegistry
        self.eventCenter = eventCenter

        setup()
    }

    func update(currencies: [Currency]?, chainAssets: [ChainAsset]) {
        contextLock.lock()
        context = Context(
            currencies: currencies,
            chainAssets: chainAssets,
            revision: context.revision &+ 1
        )
        contextLock.unlock()
    }

    var needsFollowUpFetch: Bool {
        contextLock.lock()
        defer { contextLock.unlock() }

        guard let lastCompletedRevision else {
            return false
        }

        return lastCompletedRevision != context.revision
    }

    func fetchOperation() -> CompoundOperationWrapper<[PriceData]?> {
        let context = contextSnapshot()
        guard context.chainAssets.isNotEmpty, context.currencies?.isNotEmpty == true else {
            let wrapper: CompoundOperationWrapper<[PriceData]?> = .createWithError(
                PriceDataSourceError.inputDataMissed
            )
            trackFetchRevision(of: wrapper.targetOperation, revision: context.revision)
            return wrapper
        }

        let coingeckoOperation = createCoingeckoOperation(for: context)
        let chainlinkOperations = createChainlinkOperations(for: context)
        let soraSubqueryOperation = createSoraSubqueryOperation(for: context)
        let cachedPricesWrapper = priceCacheReader.fetchPricesOperation()

        let targetOperation: BaseOperation<[PriceData]?> = ClosureOperation { [weak self] in
            guard let self else {
                throw PriceDataSourceError.memoryError
            }

            let chainlinkPrices = chainlinkOperations.compactMap {
                try? $0.extractNoCancellableResultData()
            }
            let cachedPrices = Self.relevantCachedPrices(
                try? cachedPricesWrapper.targetOperation.extractNoCancellableResultData(),
                for: context
            )

            let coingeckoPrices: [PriceData]
            do {
                coingeckoPrices = try coingeckoOperation.extractNoCancellableResultData()
            } catch {
                Logger.shared.error("COINGECKO_PRICE_FETCH_FAILED")
                coingeckoPrices = cachedPrices
            }

            let soraSubqueryPrices: [PriceData]
            let retainedSoraPrices: [PriceData]
            do {
                soraSubqueryPrices = try soraSubqueryOperation.extractNoCancellableResultData()
                retainedSoraPrices = []
            } catch {
                Logger.shared.error("POLKASWAP_PI_PRICE_FETCH_FAILED")
                soraSubqueryPrices = []
                retainedSoraPrices = cachedPrices
            }

            let mergedPrices = self.merge(
                coingeckoPrices: coingeckoPrices,
                chainlinkPrices: chainlinkPrices,
                chainAssets: context.chainAssets
            )

            return Self.mergeSoraPrices(
                coingeckoPrices: mergedPrices,
                soraSubqueryPrices: soraSubqueryPrices,
                retainedSoraPrices: retainedSoraPrices,
                chainAssets: context.chainAssets
            )
        }

        targetOperation.addDependency(coingeckoOperation)
        targetOperation.addDependency(soraSubqueryOperation)
        targetOperation.addDependency(cachedPricesWrapper.targetOperation)
        chainlinkOperations.forEach {
            targetOperation.addDependency($0)
        }

        let wrapper = CompoundOperationWrapper(
            targetOperation: targetOperation,
            dependencies: [coingeckoOperation, soraSubqueryOperation]
                + chainlinkOperations
                + cachedPricesWrapper.allOperations
        )
        trackFetchRevision(of: targetOperation, revision: context.revision)

        return wrapper
    }

    static func mergeSoraPrices(
        coingeckoPrices: [PriceData],
        soraSubqueryPrices: [PriceData],
        retainedSoraPrices: [PriceData] = [],
        chainAssets: [ChainAsset]
    ) -> [PriceData] {
        let soraKeys = Set(soraSubqueryPrices.map {
            PriceKey(currencyId: $0.currencyId, priceId: $0.priceId)
        })
        let missingFallbackPrices = makePrices(
            from: coingeckoPrices,
            for: .sorasubquery,
            chainAssets: chainAssets
        ).filter {
            !soraKeys.contains(
                PriceKey(currencyId: $0.currencyId, priceId: $0.priceId)
            )
        }

        let soraPriceIds = Set(
            chainAssets
                .filter { $0.asset.priceProvider?.type == .sorasubquery }
                .compactMap { $0.asset.priceId }
        )
        let validRetainedPrices = retainedSoraPrices.filter {
            $0.currencyId == Currency.defaultCurrency().id
                && soraPriceIds.contains($0.priceId)
                && PriceValueValidator.isStrictlyPositiveDecimal(
                    $0.price,
                    maximumBytes: 256
                )
        }

        return mergeUniquePrices(
            coingeckoPrices
                + validRetainedPrices
                + missingFallbackPrices
                + soraSubqueryPrices
        )
    }

    static func shouldFetchSoraPrices(for currencies: [Currency]?) -> Bool {
        currencies?.contains { $0.id == Currency.defaultCurrency().id } == true
    }

    private static func relevantCachedPrices(
        _ prices: [PriceData]?,
        for context: Context
    ) -> [PriceData] {
        let currencyIds = Set(context.currencies?.map(\.id) ?? [])
        let priceIds = Set(context.chainAssets.compactMap { $0.asset.priceId })

        return prices?.filter {
            currencyIds.contains($0.currencyId)
                && priceIds.contains($0.priceId)
                && PriceValueValidator.isStrictlyPositiveDecimal(
                    $0.price,
                    maximumBytes: 256
                )
        } ?? []
    }

    private func merge(
        coingeckoPrices: [PriceData],
        chainlinkPrices: [PriceData],
        chainAssets: [ChainAsset]
    ) -> [PriceData] {
        if chainlinkPrices.isEmpty {
            let prices = Self.makePrices(
                from: coingeckoPrices,
                for: .chainlink,
                chainAssets: chainAssets
            )
            return coingeckoPrices + prices
        }
        let chainAssetPriceIds = Set(chainAssets.compactMap { $0.asset.coingeckoPriceId })
        let chainlinkPriceIds = Set(chainlinkPrices.compactMap { $0.coingeckoPriceId })

        let replacedFiatDayChange: [PriceData] = chainlinkPrices.map { chainlinkPrice in
            let coingeckoPrice = coingeckoPrices.first {
                $0.coingeckoPriceId == chainlinkPrice.coingeckoPriceId
            }
            return chainlinkPrice.replaceFiatDayChange(
                fiatDayChange: coingeckoPrice?.fiatDayChange
            )
        }

        let filtered = coingeckoPrices.filter { coingeckoPrice in
            guard let coingeckoPriceId = coingeckoPrice.coingeckoPriceId else {
                return true
            }
            return !chainAssetPriceIds.intersection(chainlinkPriceIds).contains(coingeckoPriceId)
        }

        return filtered + replacedFiatDayChange
    }

    private static func makePrices(
        from coingeckoPrices: [PriceData],
        for type: PriceProviderType,
        chainAssets: [ChainAsset]
    ) -> [PriceData] {
        let typePriceChainAsset = chainAssets
            .filter { $0.asset.priceProvider?.type == type }

        var seenKeys = Set<PriceKey>()
        return typePriceChainAsset.flatMap { chainAsset -> [PriceData] in
            guard
                let coingeckoPriceId = chainAsset.asset.coingeckoPriceId,
                let priceId = chainAsset.asset.priceId
            else {
                return []
            }

            return coingeckoPrices
                .filter { $0.priceId == coingeckoPriceId }
                .compactMap { price in
                    let key = PriceKey(
                        currencyId: price.currencyId,
                        priceId: priceId
                    )
                    guard seenKeys.insert(key).inserted else {
                        return nil
                    }

                    return PriceData(
                        currencyId: price.currencyId,
                        priceId: priceId,
                        price: price.price,
                        fiatDayChange: price.fiatDayChange,
                        coingeckoPriceId: coingeckoPriceId
                    )
                }
        }
    }

    private static func mergeUniquePrices(_ prices: [PriceData]) -> [PriceData] {
        var keys: [PriceKey] = []
        var pricesByKey: [PriceKey: PriceData] = [:]

        prices.forEach { price in
            let key = PriceKey(currencyId: price.currencyId, priceId: price.priceId)
            if pricesByKey[key] == nil {
                keys.append(key)
            }
            pricesByKey[key] = price
        }

        return keys.compactMap { pricesByKey[$0] }
    }

    private func createSoraSubqueryOperation(
        for context: Context
    ) -> BaseOperation<[PriceData]> {
        guard Self.shouldFetchSoraPrices(for: context.currencies) else {
            return BaseOperation.createWithResult([])
        }

        let chainAssets = context.chainAssets.filter {
            $0.asset.priceProvider?.type == .sorasubquery
        }
        guard chainAssets.isNotEmpty else {
            return BaseOperation.createWithResult([])
        }

        return soraOperationFactory.fetchPriceOperation(for: chainAssets)
    }

    private func createCoingeckoOperation(
        for context: Context
    ) -> BaseOperation<[PriceData]> {
        let currencies = context.currencies ?? []
        let priceIds = context.chainAssets
            .compactMap { $0.asset.coingeckoPriceId }
            .uniq(predicate: { $0 })
        guard priceIds.isNotEmpty else {
            return BaseOperation.createWithResult([])
        }

        return coingeckoOperationFactory.fetchPriceOperation(
            for: priceIds,
            currencies: currencies
        )
    }

    private func createChainlinkOperations(
        for context: Context
    ) -> [BaseOperation<PriceData>] {
        guard
            context.currencies?.count == 1,
            context.currencies?.first?.id == Currency.defaultCurrency().id
        else {
            return []
        }

        let chainlinkProvider = context.chainAssets
            .map(\.chain)
            .first { $0.options?.contains(.chainlinkProvider) == true }
        let connection = chainlinkProvider.flatMap {
            chainRegistry.getEthereumConnection(for: $0.chainId)
        }

        return context.chainAssets
            .filter { $0.asset.priceProvider?.type == .chainlink }
            .compactMap {
                chainlinkOperationFactory.priceCall(for: $0, connection: connection)
            }
    }

    private func contextSnapshot() -> Context {
        contextLock.lock()
        defer { contextLock.unlock() }
        return context
    }

    private func trackFetchRevision(
        of operation: BaseOperation<[PriceData]?>,
        revision: UInt64
    ) {
        let existingConfiguration = operation.configurationBlock
        operation.configurationBlock = { [weak self] in
            existingConfiguration?()
            self?.markFetchCompleted(revision: revision)
        }

        let existingCompletion = operation.completionBlock
        operation.completionBlock = { [weak self, weak operation] in
            existingCompletion?()
            guard operation?.isCancelled == true else {
                return
            }

            self?.markFetchCompleted(revision: revision)
        }
    }

    private func markFetchCompleted(revision: UInt64) {
        contextLock.lock()
        lastCompletedRevision = max(lastCompletedRevision ?? revision, revision)
        contextLock.unlock()
    }

    private func setup() {
        eventCenter.add(observer: self)
    }
}

extension PriceDataSource: EventVisitorProtocol {
    func processMetaAccountChanged(event: MetaAccountModelChangedEvent) {
        contextLock.lock()
        context.currencies = (
            context.currencies.or([]) + [event.account.selectedCurrency]
        ).uniq(predicate: { $0.id })
        context.revision &+= 1
        contextLock.unlock()
    }
}
