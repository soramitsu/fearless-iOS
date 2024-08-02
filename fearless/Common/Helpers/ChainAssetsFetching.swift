import RobinHood
import Foundation
import SSFUtils
import SSFModels

protocol ChainAssetFetchingProtocol {
    func fetch(
        shouldUseCache: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    )
    func fetchAwaitOperation(
        shouldUseCache: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors: [ChainAssetsFetching.SortDescriptor]
    ) -> BaseOperation<[ChainAsset]>

    func fetchAwait(
        shouldUseCache: Bool,
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors: [ChainAssetsFetching.SortDescriptor]
    ) async throws -> [ChainAsset]
}

final class ChainAssetsFetching: ChainAssetFetchingProtocol {
    enum Filter: Equatable {
        case chainId(ChainModel.Id)
        case hasStaking(Bool)
        case hasCrowdloans(Bool)
        case assetName(String)
        case assetNames([String])
        case search(String)
        case ecosystem(ChainEcosystem)
        case chainIds([ChainModel.Id])
        case supportNfts
        case enabled(wallet: MetaAccountModel)
        case enabledChains

        var searchText: String? {
            switch self {
            case let .search(text):
                return text
            default:
                return nil
            }
        }
    }

    enum SortDescriptor {
        case price(SortOrder)
        case assetName(SortOrder)
        case chainName(SortOrder)
        case isTest(SortOrder)
        case isPolkadotOrKusama(SortOrder)
        case assetId(SortOrder)
    }

    enum SortOrder {
        case ascending
        case descending
    }

    private enum Sort {
        case price(SortOrder)
        case assetName(SortOrder)
        case chainName(SortOrder)
        case isTest(SortOrder)
        case isPolkadotOrKusama(SortOrder)
        case assetId(SortOrder)
    }

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue

    private var allChainAssets: [ChainAsset]?

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        operationQueue: OperationQueue = OperationQueue()
    ) {
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
    }

    func fetch(
        shouldUseCache: Bool,
        filters: [Filter],
        sortDescriptors: [SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        if shouldUseCache {
            fetchFromCache(filters: filters, sortDescriptors: sortDescriptors, completionBlock: completionBlock)
        } else {
            allChainAssets = nil
            fetchFromDatabase(filters: filters, sortDescriptors: sortDescriptors, completionBlock: completionBlock)
        }
    }

    func fetchAwaitOperation(
        shouldUseCache: Bool,
        filters: [Filter],
        sortDescriptors: [SortDescriptor]
    ) -> BaseOperation<[ChainAsset]> {
        AwaitOperation { [weak self] in
            guard let self = self else {
                throw BaseOperationError.parentOperationCancelled
            }
            return try await self.fetchAwait(
                shouldUseCache: shouldUseCache,
                filters: filters,
                sortDescriptors: sortDescriptors
            )
        }
    }

    func fetchAwait(
        shouldUseCache: Bool,
        filters: [Filter],
        sortDescriptors: [SortDescriptor]
    ) async throws -> [ChainAsset] {
        try await withCheckedThrowingContinuation { continuation in
            fetch(
                shouldUseCache: shouldUseCache,
                filters: filters,
                sortDescriptors: sortDescriptors,
                completionBlock: { result in
                    switch result {
                    case let .success(chainAsset):
                        return continuation.resume(returning: chainAsset)
                    case let .failure(error):
                        return continuation.resume(throwing: error)
                    case .none:
                        return continuation.resume(throwing: ConvenienceError(error: "None completion block"))
                    }
                }
            )
        }
    }
}

private extension ChainAssetsFetching {
    func fetchFromCache(
        filters: [Filter],
        sortDescriptors: [SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        func prepareSortAndFilter(chainAssets: [ChainAsset]) {
            let filtredChainAssets = filter(chainAssets: chainAssets, filters: filters)

            prepareSortIfNeeded(
                chainAssets: filtredChainAssets,
                sortDescriptors: sortDescriptors,
                completionBlock: completionBlock
            )
        }

        if let allChainAssets = allChainAssets {
            prepareSortAndFilter(chainAssets: allChainAssets)
        } else {
            fetchFromDatabase(filters: [], sortDescriptors: []) { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                case let .success(chainAssets):
                    strongSelf.allChainAssets = chainAssets
                    prepareSortAndFilter(chainAssets: chainAssets)
                case let .failure(error):
                    completionBlock(.failure(error))
                case .none:
                    completionBlock(.none)
                }
            }
        }
    }

    func fetchFromDatabase(
        filters: [Filter],
        sortDescriptors: [SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        let operation = chainRepository.fetchAllOperation(with: .none)
        operation.completionBlock = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            switch operation.result {
            case let .success(chains):
                var chainAssets = chains.map(\.chainAssets).reduce([], +)

                chainAssets = strongSelf.filter(chainAssets: chainAssets, filters: filters)

                strongSelf.prepareSortIfNeeded(
                    chainAssets: chainAssets,
                    sortDescriptors: sortDescriptors,
                    completionBlock: completionBlock
                )
            case let .failure(error):
                completionBlock(.failure(error))
            case .none:
                completionBlock(.none)
            }
        }
        operationQueue.addOperation(operation)
    }

    func filter(chainAssets: [ChainAsset], filters: [Filter]) -> [ChainAsset] {
        var filteredChainAssets: [ChainAsset] = chainAssets
        filters.forEach { filter in
            filteredChainAssets = apply(filter: filter, for: filteredChainAssets)
        }
        return filteredChainAssets
    }

    func apply(filter: Filter, for chainAssets: [ChainAsset]) -> [ChainAsset] {
        switch filter {
        case let .chainId(id):
            return chainAssets.filter { $0.chain.chainId == id }
        case let .hasCrowdloans(hasCrowdloans):
            return chainAssets.filter { $0.chain.hasCrowdloans == hasCrowdloans }
        case let .hasStaking(hasStaking):
            return chainAssets.filter { chainAsset in
                chainAsset.hasStaking == hasStaking
            }
        case let .assetName(name):
            return chainAssets.filter { $0.asset.symbol.lowercased() == name.lowercased() }
        case let .search(name):
            return chainAssets.filter {
                $0.asset.symbol.lowercased().contains(name.lowercased())
            }
        case let .ecosystem(ecosystem):
            return chainAssets.filter {
                return $0.defineEcosystem() == ecosystem
            }
        case let .chainIds(ids):
            return chainAssets.filter { ids.contains($0.chain.chainId) }
        case .supportNfts:
            return chainAssets.filter { $0.chain.isEthereum }
        case let .assetNames(names):
            return chainAssets.filter { names.map { $0.lowercased() }.contains($0.asset.symbol.lowercased()) }
        case let .enabled(wallet):
            let enabled: [String] = wallet.assetsVisibility
                .filter { !$0.hidden }
                .map { $0.assetId }
            return chainAssets.filter { enabled.contains($0.identifier) }
        case .enabledChains:
            return chainAssets.filter { !$0.chain.disabled }
        }
    }

    private func prepareSortIfNeeded(
        chainAssets: [ChainAsset],
        sortDescriptors: [SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        let sorts: [Sort] = convertSorts(
            sortDescriptors: sortDescriptors
        )

        completionBlock(.success(sort(chainAssets: chainAssets, sorts: sorts)))
    }

    private func sort(chainAssets: [ChainAsset], sorts: [Sort]) -> [ChainAsset] {
        let lock = NSLock()
        var sortedChainAssets: [ChainAsset] = chainAssets
        sorts.reversed().forEach { sort in
            sortedChainAssets = lock.with { apply(sort: sort, chainAssets: sortedChainAssets) }
        }
        return sortedChainAssets
    }

    private func apply(sort: Sort, chainAssets: [ChainAsset]) -> [ChainAsset] {
        switch sort {
        case let .price(order):
            return sortByPrice(chainAssets: chainAssets, order: order)
        case let .assetId(order):
            return sortByAssetId(chainAssets: chainAssets, order: order)
        case let .assetName(order):
            return sortByAssetName(chainAssets: chainAssets, order: order)
        case let .chainName(order):
            return sortByChainName(chainAssets: chainAssets, order: order)
        case let .isTest(order):
            return sortByTestnet(chainAssets: chainAssets, order: order)
        case let .isPolkadotOrKusama(order):
            return sortByPolkadotOrKusama(chainAssets: chainAssets, order: order)
        }
    }

    private func convertSorts(sortDescriptors: [SortDescriptor]) -> [Sort] {
        sortDescriptors.map { sortDescriptor in
            switch sortDescriptor {
            case let .price(order):
                return .price(order)
            case let .isPolkadotOrKusama(order):
                return .isPolkadotOrKusama(order)
            case let .chainName(order):
                return .chainName(order)
            case let .assetId(order):
                return .assetId(order)
            case let .isTest(order):
                return .isTest(order)
            case let .assetName(order):
                return .assetName(order)
            }
        }
    }

    func sortByPrice(chainAssets: [ChainAsset], order: SortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.asset.price ?? 0 < $1.asset.price ?? 0
            case .descending:
                return $0.asset.price ?? 0 > $1.asset.price ?? 0
            }
        }
    }

    func sortByAssetName(chainAssets: [ChainAsset], order: SortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.asset.symbol < $1.asset.symbol
            case .descending:
                return $0.asset.symbol > $1.asset.symbol
            }
        }
    }

    private func sortByChainName(chainAssets: [ChainAsset], order: SortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.chain.name < $1.chain.name
            case .descending:
                return $0.chain.name > $1.chain.name
            }
        }
    }

    func sortByTestnet(chainAssets: [ChainAsset], order: SortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.chain.isTestnet.intValue < $1.chain.isTestnet.intValue
            case .descending:
                return $0.chain.isTestnet.intValue > $1.chain.isTestnet.intValue
            }
        }
    }

    func sortByPolkadotOrKusama(chainAssets: [ChainAsset], order: SortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.chain.isPolkadotOrKusama.intValue < $1.chain.isPolkadotOrKusama.intValue
            case .descending:
                return $0.chain.isPolkadotOrKusama.intValue > $1.chain.isPolkadotOrKusama.intValue
            }
        }
    }

    func sortByAssetId(chainAssets: [ChainAsset], order: SortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.asset.id < $1.asset.id
            case .descending:
                return $0.asset.id > $1.asset.id
            }
        }
    }
}
