import UIKit
import FearlessFoundation
import RobinHood
import FearlessSecureStorage
import SSFStorageQueryKit

final class ChainAssetListAssembly {
    private struct AccountInfoServices {
        let accountInfoFetching: AccountInfoFetching
        let ethereumRemoteBalanceFetching: EthereumRemoteBalanceFetching
        let chainsIssuesCenter: ChainsIssuesCenter
        let accountInfoRemoteService: AccountInfoRemoteService
    }

    static func configureModule(
        wallet: MetaAccountModel,
        keyboardAdoptable: Bool
    ) -> ChainAssetListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        let dependencyContainer = ChainAssetListDependencyContainer()
        let accountInfoServices = createAccountInfoServices(wallet: wallet)
        let chainAssetFetching = createChainAssetFetching()
        let chainSettingsRepositoryFactory = ChainSettingsRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let chainSettingsRepostiry = chainSettingsRepositoryFactory.createAsyncRepository()
        let operationQueue = OperationManagerFacade.sharedDefaultQueue
        let pricesService = PricesService.shared

        let interactor = ChainAssetListInteractor(
            wallet: wallet,
            eventCenter: EventCenter.shared,
            accountRepository: AnyDataProviderRepository(accountRepository),
            accountInfoFetchingProvider: accountInfoServices.accountInfoFetching,
            dependencyContainer: dependencyContainer,
            ethRemoteBalanceFetching: accountInfoServices.ethereumRemoteBalanceFetching,
            chainAssetFetching: chainAssetFetching,
            userDefaultsStorage: SettingsManager.shared,
            chainsIssuesCenter: accountInfoServices.chainsIssuesCenter,
            chainSettingsRepository: AsyncAnyRepository(chainSettingsRepostiry),
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            accountInfoRemoteService: accountInfoServices.accountInfoRemoteService,
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

    private static func createAccountInfoServices(wallet: MetaAccountModel) -> AccountInfoServices {
        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let accountInfoRepository = SubstrateRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
            .createAccountInfoStorageItemRepository()

        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: chainRegistry,
            operationQueue: OperationQueue()
        )

        let ethereumRemoteBalanceFetching = EthereumRemoteBalanceFetching(
            chainRegistry: chainRegistry,
            repositoryWrapper: BalanceRepositoryCacheWrapper(
                logger: Logger.shared,
                repository: accountInfoRepository,
                operationManager: OperationManagerFacade.sharedManager
            )
        )

        let accountInfoRemoteService = createAccountInfoRemoteService(
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            accountInfoRepository: accountInfoRepository
        )

        return AccountInfoServices(
            accountInfoFetching: accountInfoFetching,
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            chainsIssuesCenter: createChainsIssuesCenter(
                wallet: wallet,
                accountInfoRepository: accountInfoRepository,
                ethereumFetching: ethereumRemoteBalanceFetching
            ),
            accountInfoRemoteService: accountInfoRemoteService
        )
    }

    private static func createChainAssetFetching() -> ChainAssetsFetching {
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        return ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
    }

    private static func createChainsIssuesCenter(
        wallet: MetaAccountModel,
        accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>,
        ethereumFetching: AccountInfoFetchingProtocol
    ) -> ChainsIssuesCenter {
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let missingAccountHelper = MissingAccountFetcher(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let accountInfoFetcher = CompositeAccountInfoFetching(
            substrateFetching: AccountInfoFetching(
                accountInfoRepository: AnyDataProviderRepository(accountInfoRepository),
                chainRegistry: ChainRegistryFacade.sharedRegistry,
                operationQueue: OperationManagerFacade.sharedDefaultQueue
            ),
            ethereumFetching: ethereumFetching
        )

        return ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper,
            accountInfoFetcher: accountInfoFetcher
        )
    }

    private static func createAccountInfoRemoteService(
        ethereumRemoteBalanceFetching: AccountInfoFetchingProtocol,
        accountInfoRepository: AnyDataProviderRepository<AccountInfoStorageWrapper>
    ) -> AccountInfoRemoteService {
        let tonBalanceRepositoryWrapper = BalanceRepositoryCacheWrapper(
            logger: Logger.shared,
            repository: accountInfoRepository,
            operationManager: OperationManagerFacade.sharedManager
        )
        let tonJettonInjector = TonJettonInjectorImpl(
            chainModelRepository: AsyncAnyRepository(ChainRepositoryFactory().createAsyncRepository()),
            eventCenter: EventCenter.shared,
            logger: Logger.shared
        )
        let tonRemoteBalanceFetching = TonRemoteBalanceFetchingImpl(
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            repositoryWrapper: tonBalanceRepositoryWrapper,
            jettonInjector: tonJettonInjector
        )

        return AccountInfoRemoteServiceDefault(
            ethereumRemoteBalanceFetching: ethereumRemoteBalanceFetching,
            tonRemoteBalanceFetching: tonRemoteBalanceFetching,
            storagePerformer: SSFStorageQueryKit.StorageRequestPerformerDefault(
                chainRegistry: ChainRegistryFacade.sharedRegistry
            )
        )
    }
}
