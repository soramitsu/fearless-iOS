import UIKit
import SoraFoundation
import RobinHood
import SoraKeystore

final class ChainAssetListAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        soraCardViewController: UIViewController? = nil
    ) -> ChainAssetListModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createChainStorageItemRepository()

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

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
            missingAccountHelper: missingAccountHelper
        )

        let interactor = ChainAssetListInteractor(
            wallet: wallet,
            chainAssetFetching: chainAssetFetching,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            assetRepository: AnyDataProviderRepository(assetRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: EventCenter.shared,
            chainsIssuesCenter: chainsIssuesCenter,
            accountRepository: AnyDataProviderRepository(accountRepository),
            settings: SettingsManager.shared
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
            soraCardViewController: soraCardViewController,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
