import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore
import SSFStorageQueryKit
import SSFModels

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

        let remoteBalanceService = ServiceAssembly.shared.accountInfoRemoteServiceDefault()
        let chainSettingsRepositoryFactory = ChainSettingsRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let chainSettingsRepostiry = chainSettingsRepositoryFactory.createAsyncRepository()
        let pricesService = PricesService.shared

        let interactor = ChainAssetListInteractor(
            wallet: wallet,
            eventCenter: EventCenter.shared,
            accountRepository: AnyDataProviderRepository(accountRepository),
            accountInfoFetchingProvider: accountInfoFetching,
            dependencyContainer: dependencyContainer,
            remoteBalanceService: remoteBalanceService,
            chainAssetFetching: chainAssetFetching,
            userDefaultsStorage: SettingsManager.shared,
            chainsIssuesCenter: chainsIssuesCenter,
            chainSettingsRepository: AsyncAnyRepository(chainSettingsRepostiry),
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            logger: ServiceAssembly.shared.logger,
            pricesService: pricesService
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
        
        presenter.bannersInput = bannersModule?.input

        return (view, presenter)
    }

    private static func configureBannersModule(moduleOutput: BannersModuleOutput?) -> BannersModuleCreationResult? {
        BannersAssembly.configureModule(output: moduleOutput, type: .independent, wallet: nil)
    }
}
