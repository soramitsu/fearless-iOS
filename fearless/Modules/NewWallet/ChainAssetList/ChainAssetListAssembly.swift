import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFStorageQueryKit

final class ChainAssetListAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        keyboardAdoptable: Bool
    ) -> ChainAssetListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationQueue()
        )

        let dependencyContainer = ChainAssetListDependencyContainer()

        let ethereumBalanceRepositoryCacheWrapper = EthereumBalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: accountInfoRepository,
            operationManager: OperationManagerFacade.sharedManager
        )
        let ethereumRemoteBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: chainRegistry,
            repositoryWrapper: ethereumBalanceRepositoryCacheWrapper
        )
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let missingAccountHelper = MissingAccountFetcher(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let accountInfoFetcher = AccountInfoFetching(
            accountInfoRepository: AnyDataProviderRepository(accountInfoRepository),
            chainRegistry: chainRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let chainsIssuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper,
            accountInfoFetcher: accountInfoFetcher
        )
        let runtimeMetadataRepository: AsyncCoreDataRepositoryDefault<RuntimeMetadataItem, CDRuntimeMetadataItem> =
            SubstrateDataStorageFacade.shared.createAsyncRepository()
        let chainSettingsRepositoryFactory = ChainSettingsRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let chainSettingsRepostiry = chainSettingsRepositoryFactory.createAsyncRepository()
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let assetRepository = AssetRepositoryFactory().createRepository()
        let pricesService = PricesService.shared
        let storagePerformer = SSFStorageQueryKit.StorageRequestPerformerDefault(
            chainRegistry: chainRegistry
        )

        let accountInfoRemoteService = AccountInfoRemoteServiceDefault(
            runtimeItemRepository: AsyncAnyRepository(runtimeMetadataRepository),
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            storagePerformer: storagePerformer
        )

        let interactor = ChainAssetListInteractor(
            wallet: wallet,
            eventCenter: EventCenter.shared,
            accountRepository: AnyDataProviderRepository(accountRepository),
            accountInfoFetchingProvider: accountInfoFetching,
            dependencyContainer: dependencyContainer,
            ethRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            chainAssetFetching: chainAssetFetching,
            userDefaultsStorage: SettingsManager.shared,
            chainsIssuesCenter: chainsIssuesCenter,
            chainSettingsRepository: AsyncAnyRepository(chainSettingsRepostiry),
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            accountInfoRemoteService: accountInfoRemoteService,
            pricesService: pricesService,
            operationQueue: operationQueue
        )
        let router = ChainAssetListRouter()
        let viewModelFactory = ChainAssetListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            wallet: wallet,
            viewModelFactory: viewModelFactory
        )

        let bannersModule = Self.configureBannersModule(moduleOutput: presenter)
        let bannersViewController = bannersModule?.view.controller
        let view = ChainAssetListViewController(
            bannersViewController: bannersViewController,
            output: presenter,
            keyboardAdoptable: keyboardAdoptable,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    private static func configureBannersModule(moduleOutput: BannersModuleOutput?) -> BannersModuleCreationResult? {
        BannersAssembly.configureModule(output: moduleOutput, type: .independent, wallet: nil)
    }
}
