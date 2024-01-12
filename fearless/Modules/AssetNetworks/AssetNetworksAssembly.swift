import UIKit
import SoraFoundation
import SSFModels
import RobinHood

final class AssetNetworksAssembly {
    static func configureModule(chainAsset: ChainAsset, wallet: MetaAccountModel) -> AssetNetworksModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let priceLocalSubscriber = PriceLocalStorageSubscriberImpl.shared
        let chainRepository = ChainRepositoryFactory().createRepository(
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
        let interactor = AssetNetworksInteractor(
            chainAsset: chainAsset,
            chainAssetFetching: chainAssetFetching,
            priceLocalSubscriber: priceLocalSubscriber,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter
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
