import UIKit
import SoraFoundation
import SSFModels
import RobinHood
import SoraKeystore
import SSFStorageQueryKit

final class AssetManagementAssembly {
    static func configureModule(
        networkFilter: NetworkManagmentFilter?,
        wallet: MetaAccountModel,
        visibilityFilter: ManageAssetsFilter = .all
    ) -> AssetManagementModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain()
        )
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        let accountInfoFetchingProvider = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let viewModelFactory = AssetManagementViewModelFactoryDefault(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let repository = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        ).createAccountInfoStorageItemRepository()
        let ethereumBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let ethereumRemoteBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: chainRegistry,
            repositoryWrapper: ethereumBalanceRepositoryWrapper
        )

        let tonBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: repository,
            operationManager: OperationManagerFacade.sharedManager
        )

        let tonChainRepository = ChainRepositoryFactory().createAsyncRepository()
        let tonJettonInjector = TonJettonInjectorImpl(
            chainModelRepository: AsyncAnyRepository(tonChainRepository),
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
        let dynamicAssetCatalogInjector = DynamicAssetCatalogInjectorImpl(
            chainModelRepository: AsyncAnyRepository(tonChainRepository),
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )

        let tonRemoteBalanceFetching = TonRemoteBalanceFetchingImpl(
            chainRegistry: chainRegistry,
            repositoryWrapper: tonBalanceRepositoryWrapper,
            jettonInjector: tonJettonInjector
        )

        let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: chainRegistry
        )

        let accountInfoRemote = AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            tonRemoteBalanceFetching: tonRemoteBalanceFetching,
            bitcoinBalanceSync: BitcoinBalanceSync(discovery: BitcoinReceiveDiscovery(client: BitcoinFailoverIndexerClient())),
            solanaBalanceSync: SolanaRpcBalanceSync.mainnet,
            dynamicAssetCatalogInjector: dynamicAssetCatalogInjector,
            storagePerformer: storagePerformer
        )

        let interactor = AssetManagementInteractor(
            chainAssetFetching: chainAssetFetching,
            accountInfoFetchingProvider: accountInfoFetchingProvider,
            eventCenter: EventCenter.shared,
            accountInfoRemoteService: accountInfoRemote
        )
        let router = AssetManagementRouter()

        let presenter = AssetManagementPresenter(
            wallet: wallet,
            networkFilter: networkFilter,
            logger: Logger.shared,
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            visibilityFilter: visibilityFilter
        )

        let view = AssetManagementViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
