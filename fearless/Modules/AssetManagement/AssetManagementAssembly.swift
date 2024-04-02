import UIKit
import SoraFoundation
import SSFModels
import RobinHood
import SoraKeystore

final class AssetManagementAssembly {
    static func configureModule(
        networkFilter: NetworkManagmentFilter?,
        wallet: MetaAccountModel
    ) -> AssetManagementModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
        let chainRepository = ChainRepositoryFactory().createRepository()
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

        let interactor = AssetManagementInteractor(
            chainAssetFetching: chainAssetFetching,
            priceLocalSubscriber: priceLocalSubscriber,
            accountInfoFetchingProvider: accountInfoFetchingProvider,
            eventCenter: EventCenter.shared
        )
        let router = AssetManagementRouter()

        let presenter = AssetManagementPresenter(
            wallet: wallet,
            networkFilter: networkFilter,
            logger: Logger.shared,
            viewModelFactory: viewModelFactory,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = AssetManagementViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
