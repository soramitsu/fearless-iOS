import RobinHood
import Foundation
import FearlessUtils

protocol ChainAssetFetchingProtocol {
    func fetch(
        filters: [ChainAssetsFetching.Filter],
        sortDescriptors: [ChainAssetsFetching.SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    )
}

final class ChainAssetsFetching: ChainAssetFetchingProtocol {
    enum Filter {
        case chainId(ChainModel.Id)
        case hasStaking(Bool)
        case hasCrowdloans(Bool)
        case assetName(String)
        case search(String)
    }

    enum SortDescriptor {
        case price(SortOrder)
        case balance(SortOrder)
        case usdBalance(SortOrder)
        case assetName(SortOrder)
        case chainName(SortOrder)
        case isTest(SortOrder)
        case isPolkadotOrKusama(SortOrder)
        case assetId(SortOrder)

        var balanceRequired: Bool {
            switch self {
            case .balance, .usdBalance:
                return true
            default:
                return false
            }
        }
    }

    enum SortOrder {
        case ascending
        case descending
    }

    private enum Sort {
        case price(SortOrder)
        case balance(SortOrder, [ChainAssetKey: AccountInfo?])
        case usdBalance(SortOrder, [ChainAssetKey: AccountInfo?])
        case assetName(SortOrder)
        case chainName(SortOrder)
        case isTest(SortOrder)
        case isPolkadotOrKusama(SortOrder)
        case assetId(SortOrder)
    }

    private let chainRepository: AnyDataProviderRepository<ChainModel>
    private let operationQueue: OperationQueue
    private let meta: MetaAccountModel
    private let accountInfoFetching: AccountInfoFetching
    private var accountInfos: [ChainAssetKey: AccountInfo?] = [:]

    init(
        chainRepository: AnyDataProviderRepository<ChainModel>,
        accountInfoFetching: AccountInfoFetching,
        operationQueue: OperationQueue = OperationQueue(),
        meta: MetaAccountModel
    ) {
        self.chainRepository = chainRepository
        self.operationQueue = operationQueue
        self.accountInfoFetching = accountInfoFetching
        self.meta = meta
    }

    func fetch(
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
}

private extension ChainAssetsFetching {
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
            return chainAssets.filter { $0.asset.name == name }
        case let .search(name):
            return chainAssets.filter {
                $0.asset.name.lowercased().contains(name.lowercased())
                    || $0.chain.name.lowercased().contains(name.lowercased())
            }
        }
    }

    private func prepareSortIfNeeded(
        chainAssets: [ChainAsset],
        sortDescriptors: [SortDescriptor],
        completionBlock: @escaping (Result<[ChainAsset], Error>?) -> Void
    ) {
        if sortDescriptors.contains(where: { $0.balanceRequired }) {
            getAccountInfo(
                for: chainAssets,
                completionBlock: { [weak self] accountInfos in
                    guard let strongSelf = self else { return }
                    let sorts: [Sort] = strongSelf.convertSorts(
                        sortDescriptors: sortDescriptors,
                        accountInfos: accountInfos
                    )

                    completionBlock(.success(strongSelf.sort(chainAssets: chainAssets, sorts: sorts)))
                }
            )
        } else {
            let sorts: [Sort] = convertSorts(
                sortDescriptors: sortDescriptors,
                accountInfos: nil
            )

            completionBlock(.success(sort(chainAssets: chainAssets, sorts: sorts)))
        }
    }

    private func getAccountInfo(
        for chainAssets: [ChainAsset],
        completionBlock: @escaping ([ChainAssetKey: AccountInfo?]) -> Void
    ) {
        let semaphore = DispatchSemaphore(value: chainAssets.count)
        chainAssets.forEach { [weak self] chainAsset in
            guard let strongSelf = self,
                  let accountId = strongSelf.meta.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
                return
            }

            strongSelf.accountInfoFetching.fetch(
                for: chainAsset,
                accountId: accountId
            ) { [weak self] chainAsset, accountInfo in
                guard let strongSelf = self else { return }
                strongSelf.accountInfos[chainAsset.uniqueKey(accountId: accountId)] = accountInfo
                semaphore.signal()
            }
        }
        semaphore.wait()
        completionBlock(accountInfos)
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
        case let .balance(order, accountInfos):
            return sortByBalance(chainAssets: chainAssets, order: order, accountInfos: accountInfos)
        case let .usdBalance(order, accountInfos):
            return sortByUsdBalance(chainAssets: chainAssets, order: order, accountInfos: accountInfos)
        }
    }

    func getBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> Decimal {
        guard let accountInfo = accountInfo else {
            return Decimal.zero
        }

        let assetInfo = chainAsset.asset.displayInfo

        let balance = Decimal.fromSubstrateAmount(
            accountInfo.data.total,
            precision: assetInfo.assetPrecision
        ) ?? 0

        return balance
    }

    func getUsdBalance(
        for chainAsset: ChainAsset,
        accountInfo: AccountInfo?
    ) -> Decimal {
        let assetInfo = chainAsset.asset.displayInfo

        var balance: Decimal
        if let accountInfo = accountInfo {
            balance = Decimal.fromSubstrateAmount(
                accountInfo.data.total,
                precision: assetInfo.assetPrecision
            ) ?? 0
        } else {
            balance = Decimal.zero
        }

        guard let priceDecimal = chainAsset.asset.price else {
            return Decimal.zero
        }

        let totalBalanceDecimal = priceDecimal * balance

        return totalBalanceDecimal
    }

    private func convertSorts(
        sortDescriptors: [SortDescriptor],
        accountInfos: [ChainAssetKey: AccountInfo?]?
    ) -> [Sort] {
        sortDescriptors.map { sortDescriptor in
            switch sortDescriptor {
            case let .price(order):
                return .price(order)
            case let .balance(order):
                if let accountInfos = accountInfos {
                    return .balance(order, accountInfos)
                } else {
                    assertionFailure("account info required for sorting")
                    return .balance(order, [:])
                }
            case let .usdBalance(order):
                if let accountInfos = accountInfos {
                    return .usdBalance(order, accountInfos)
                } else {
                    assertionFailure("account info required for sorting")
                    return .usdBalance(order, [:])
                }
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

    func sortByBalance(chainAssets: [ChainAsset], order: SortOrder, accountInfos: [ChainAssetKey: AccountInfo?]) -> [ChainAsset] {
        chainAssets.sorted { chainAsset0, chainAsset1 in
            var balance0 = Decimal.zero
            var balance1 = Decimal.zero
            guard let accountId0 = self.meta.fetch(for: chainAsset0.chain.accountRequest())?.accountId,
                  let accountId1 = self.meta.fetch(for: chainAsset0.chain.accountRequest())?.accountId else {
                return false
            }
            if let accountInfo0 = accountInfos[chainAsset0.uniqueKey(accountId: accountId0)] {
                balance0 = getBalance(for: chainAsset0, accountInfo: accountInfo0)
            }
            if let accountInfo1: AccountInfo? = accountInfos[chainAsset1.uniqueKey(accountId: accountId1)] {
                balance1 = getBalance(for: chainAsset1, accountInfo: accountInfo1)
            }
            switch order {
            case .ascending:
                return balance0 < balance1
            case .descending:
                return balance0 > balance1
            }
        }
    }

    func sortByUsdBalance(chainAssets: [ChainAsset], order: SortOrder, accountInfos: [ChainAssetKey: AccountInfo?]) -> [ChainAsset] {
        chainAssets.sorted { chainAsset0, chainAsset1 in
            var usdBalance0 = Decimal.zero
            var usdBalance1 = Decimal.zero
            guard let accountId0 = self.meta.fetch(for: chainAsset0.chain.accountRequest())?.accountId,
                  let accountId1 = self.meta.fetch(for: chainAsset0.chain.accountRequest())?.accountId else {
                return false
            }
            if let accountInfo0 = accountInfos[chainAsset0.uniqueKey(accountId: accountId0)] {
                usdBalance0 = getBalance(for: chainAsset0, accountInfo: accountInfo0)
            }
            if let accountInfo1 = accountInfos[chainAsset1.uniqueKey(accountId: accountId1)] {
                usdBalance1 = getBalance(for: chainAsset1, accountInfo: accountInfo1)
            }
            switch order {
            case .ascending:
                return usdBalance0 < usdBalance1
            case .descending:
                return usdBalance0 > usdBalance1
            }
        }
    }

    func sortByAssetName(chainAssets: [ChainAsset], order: SortOrder) -> [ChainAsset] {
        chainAssets.sorted {
            switch order {
            case .ascending:
                return $0.asset.name < $1.asset.name
            case .descending:
                return $0.asset.name > $1.asset.name
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
