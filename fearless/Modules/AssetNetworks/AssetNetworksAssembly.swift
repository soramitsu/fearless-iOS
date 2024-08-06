import UIKit
import SoraFoundation
import SSFModels
import RobinHood

final class AssetNetworksAssembly {
    static func configureModule(chainAsset: ChainAsset, wallet: MetaAccountModel) -> AssetNetworksModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )
        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let accountInfoSubscriptionAdapter = AccountInfoSubscriptionAdapter(
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            selectedMetaAccount: wallet
        )
        let missingAccountHelper = MissingAccountFetcher(
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )
        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()
        let accountInfoFetcher = AccountInfoFetching(
            accountInfoRepository: AnyDataProviderRepository(accountInfoRepository),
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let chainsIssuesCenter = ChainsIssuesCenter(
            wallet: wallet,
            networkIssuesCenter: NetworkIssuesCenter.shared,
            eventCenter: EventCenter.shared,
            missingAccountHelper: missingAccountHelper,
            accountInfoFetcher: accountInfoFetcher
        )
        let chainSettingsRepositoryFactory = ChainSettingsRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let chainSettingsRepostiry = chainSettingsRepositoryFactory.createAsyncRepository()
        let interactor = AssetNetworksInteractor(
            chainAsset: chainAsset,
            chainAssetFetching: chainAssetFetching,
            priceLocalSubscriber: priceLocalSubscriber,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            chainsIssuesCenter: chainsIssuesCenter,
            chainSettingsRepository: AsyncAnyRepository(chainSettingsRepostiry)
        )
        let router = AssetNetworksRouter()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = AssetNetworksViewModelFactory(balanceViewModelFactory: assetBalanceFormatterFactory)
        let presenter = AssetNetworksPresenter(
            interactor: interactor,
            router: router,
            localizationManager: localizationManager,
            wallet: wallet,
            viewModelFactory: viewModelFactory
        )

        let view = AssetNetworksViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
