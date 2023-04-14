import Foundation

struct CrossChainDependencies {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
}

final class CrossChainDependencyContainer {
    private var cachedDependencies: [ChainAssetKey: CrossChainDependencies] = [:]
    private let wallet: MetaAccountModel

    init(wallet: MetaAccountModel) {
        self.wallet = wallet
    }

    func prepareDependencies(for chainAsset: ChainAsset) -> CrossChainDependencies {
        if let cached = fetchFromCache(for: chainAsset) {
            return cached
        }

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        let dependencies = CrossChainDependencies(balanceViewModelFactory: balanceViewModelFactory)

        saveToCache(dependencies: dependencies, for: chainAsset)

        return dependencies
    }

    private func fetchFromCache(for chainAsset: ChainAsset) -> CrossChainDependencies? {
        guard
            let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId,
            let cached = cachedDependencies[chainAsset.uniqueKey(accountId: accountId)]
        else {
            return nil
        }

        return cached
    }

    private func saveToCache(dependencies: CrossChainDependencies, for chainAsset: ChainAsset) {
        guard let accountId = wallet.fetch(for: chainAsset.chain.accountRequest())?.accountId else {
            return
        }

        cachedDependencies[chainAsset.uniqueKey(accountId: accountId)] = dependencies
    }
}
