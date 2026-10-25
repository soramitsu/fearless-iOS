import Foundation
import RobinHood
import SSFModels
import SSFUtils

// To regenerate mock object
// Change '_AutoMockable' to 'AutoMockable'
// Run build to generate the mock
// Replace 'class' to 'actor' in genereated mock file
// Change 'AutoMockable' to '_AutoMockable' to avoid future generations
// sourcery: _AutoMockable
public protocol ChainAssetFetchingServiceProtocol: Actor {
    func fetch(filters: [AssetFilter], sorts: [AssetSort], forceUpdate: Bool) async -> [ChainAsset]
}

public enum AssetFilter: Equatable {
    case chainId(ChainModel.Id)
    case hasStaking(Bool)
    case hasCrowdloans(Bool)
    case assetName(String)
    case search(String)
    case ecosystem(ChainEcosystem)
    case chainIds([ChainModel.Id])
    case supportNfts
}

public enum AssetSort {
    case price(AssetSortOrder)
    case assetName(AssetSortOrder)
    case chainName(AssetSortOrder)
    case isTest(AssetSortOrder)
    case isPolkadotOrKusama(AssetSortOrder)
    case assetId(AssetSortOrder)
}

public enum AssetSortOrder {
    case ascending
    case descending
}

public actor ChainAssetsFetchingService {
    private var allChainAssets: [ChainAsset] = []
    private let chainAssetsFetcher: ChainAssetsFetchWorkerProtocol

    init(chainAssetsFetcher: ChainAssetsFetchWorkerProtocol) {
        self.chainAssetsFetcher = chainAssetsFetcher
    }
}

extension ChainAssetsFetchingService: ChainAssetFetchingServiceProtocol {
    public func fetch(
        filters: [AssetFilter],
        sorts: [AssetSort],
        forceUpdate: Bool
    ) async -> [ChainAsset] {
        if !allChainAssets.isEmpty, !forceUpdate {
            let filtredChainAssets = filter(chainAssets: allChainAssets, filters: filters)
            return sort(chainAssets: filtredChainAssets, sorts: sorts)
        }

        allChainAssets = await chainAssetsFetcher.getChainAssetsModels()
        let filtredChainAssets = filter(chainAssets: allChainAssets, filters: filters)
        return sort(chainAssets: filtredChainAssets, sorts: sorts)
    }
}

private extension ChainAssetsFetchingService {
    func filter(chainAssets: [ChainAsset], filters: [AssetFilter]) -> [ChainAsset] {
        var filteredChainAssets: [ChainAsset] = chainAssets
        for filter in filters {
            filteredChainAssets = apply(filter: filter, for: filteredChainAssets)
        }
        return filteredChainAssets
    }

    private func sort(chainAssets: [ChainAsset], sorts: [AssetSort]) -> [ChainAsset] {
        var sortedChainAssets: [ChainAsset] = chainAssets
        for sort in sorts.reversed() {
            sortedChainAssets = apply(sort: sort, chainAssets: sortedChainAssets)
        }
        return sortedChainAssets
    }

    func apply(filter: AssetFilter, for chainAssets: [ChainAsset]) -> [ChainAsset] {
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
                    || $0.chain.name.lowercased().contains(name.lowercased())
            }
        case let .ecosystem(ecosystem):
            return chainAssets.filter {
                $0.defineEcosystem() == ecosystem
            }
        case let .chainIds(ids):
            return chainAssets.filter { ids.contains($0.chain.chainId) }
        case .supportNfts:
            return chainAssets.filter { $0.chain.isEthereum }
        }
    }

    private func apply(sort: AssetSort, chainAssets: [ChainAsset]) -> [ChainAsset] {
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

    func sortByPrice(chainAssets: [ChainAsset], order: AssetSortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.asset.price ?? 0 < $1.asset.price ?? 0
            case .descending:
                return $0.asset.price ?? 0 > $1.asset.price ?? 0
            }
        }
    }

    func sortByAssetName(chainAssets: [ChainAsset], order: AssetSortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.asset.symbol < $1.asset.symbol
            case .descending:
                return $0.asset.symbol > $1.asset.symbol
            }
        }
    }

    private func sortByChainName(chainAssets: [ChainAsset], order: AssetSortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.chain.name < $1.chain.name
            case .descending:
                return $0.chain.name > $1.chain.name
            }
        }
    }

    func sortByTestnet(chainAssets: [ChainAsset], order: AssetSortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.chain.isTestnet.intValue < $1.chain.isTestnet.intValue
            case .descending:
                return $0.chain.isTestnet.intValue > $1.chain.isTestnet.intValue
            }
        }
    }

    func sortByPolkadotOrKusama(chainAssets: [ChainAsset], order: AssetSortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.chain.isPolkadotOrKusama.intValue < $1.chain.isPolkadotOrKusama.intValue
            case .descending:
                return $0.chain.isPolkadotOrKusama.intValue > $1.chain.isPolkadotOrKusama.intValue
            }
        }
    }

    func sortByAssetId(chainAssets: [ChainAsset], order: AssetSortOrder) -> [ChainAsset] {
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
