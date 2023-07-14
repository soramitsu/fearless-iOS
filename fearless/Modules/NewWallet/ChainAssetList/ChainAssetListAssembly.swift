import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore

final class ChainAssetListAssembly {
    static func configureModule(
        wallet: MetaAccountModel
    ) -> ChainAssetListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let substrateAccountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let ethereumAccountInfoFetching = EthereumAccountInfoFetching(
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let assetRepository = SubstrateDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(AssetModelMapper())
        )

        let missingAccountHelper = MissingAccountFetcher(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainsIssuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper,
            accountInfoFetcher: substrateAccountInfoFetching
        )

        let chainSettingsRepositoryFactory = ChainSettingsRepositoryFactory(storageFacade: UserDataStorageFacade.shared)

        let dependencyContainer = ChainAssetListDependencyContainer()

        let interactor = ChainAssetListInteractor(
            wallet: wallet,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            assetRepository: AnyDataProviderRepository(assetRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            chainsIssuesCenter: chainsIssuesCenter,
            accountRepository: AnyDataProviderRepository(accountRepository),
            accountInfoFetching: [substrateAccountInfoFetching, ethereumAccountInfoFetching],
            dependencyContainer: dependencyContainer
        )
        let router = ChainAssetListRouter()
        let viewModelFactory = ChainAssetListViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            settings: SettingsManager.shared
        )

        let presenter = ChainAssetListPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            wallet: wallet,
            viewModelFactory: viewModelFactory
        )

        let view = ChainAssetListViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
