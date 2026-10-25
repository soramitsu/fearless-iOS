import Foundation
import RobinHood

struct ChainAssetListDependencies {
    let chainAssetFetching: ChainAssetFetchingProtocol
    let accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter
}

final class ChainAssetListDependencyContainer {
    private var cachedDependencies: [MetaAccountId: ChainAssetListDependencies] = [:]

    func buildDependencies(for wallet: MetaAccountModel) -> ChainAssetListDependencies {
        if let dependencies = cachedDependencies[wallet.metaId] {
            return dependencies
        }

        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: operationQueue
        )

        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )

        let dependencies = ChainAssetListDependencies(chainAssetFetching: chainAssetFetching, accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter)
        cachedDependencies[wallet.metaId] = dependencies

        return dependencies
    }

    func resetCache(walletId: MetaAccountId) {
        cachedDependencies[walletId] = nil
    }
}
