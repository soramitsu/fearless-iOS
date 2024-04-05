import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore

final class ChainAssetListAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        isSearch: Bool
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

        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
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
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let interactor = ChainAssetListInteractor(
            wallet: wallet,
            priceLocalSubscriber: priceLocalSubscriber,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            accountRepository: AnyDataProviderRepository(accountRepository),
            accountInfoFetchingProvider: accountInfoFetching,
            dependencyContainer: dependencyContainer,
            ethRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            chainAssetFetching: chainAssetFetching,
            userDefaultsStorage: SettingsManager.shared,
            applicationHandler: ApplicationHandler(),
            walletAssetManagementHelper: WalletAssetManagementHelperImpl()
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
            viewModelFactory: viewModelFactory,
            isSearch: isSearch
        )

        let bannersModule = Self.configureBannersModule(moduleOutput: presenter)
        let bannersViewController = bannersModule?.view.controller
        let view = ChainAssetListViewController(
            bannersViewController: bannersViewController,
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    private static func configureBannersModule(moduleOutput: BannersModuleOutput?) -> BannersModuleCreationResult? {
        BannersAssembly.configureModule(output: moduleOutput)
    }
}
