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
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: operationQueue,
            meta: wallet
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
