import UIKit
import SoraFoundation
import RobinHood
import SoraUI

final class SelectAssetAssembly {
    static func configureModule(
        wallet: MetaAccountModel,
        selectedAssetId: AssetModel.Id?,
        searchTextsViewModel: TextSearchViewModel?,
        output: SelectAssetModuleOutput
    ) -> SelectAssetModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let assetRepository = SubstrateDataStorageFacade.shared.createRepository(
            mapper: AnyCoreDataMapper(AssetModelMapper())
        )
        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let operationQueue = OperationQueue()
        operationQueue.qualityOfService = .userInitiated

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )
        let accountInfoRepository = substrateRepositoryFactory.createChainStorageItemRepository()
        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
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

        let interactor = SelectAssetInteractor(
            chainAssetFetching: chainAssetFetching,
            accountInfoSubscriptionAdapter: accountInfoSubscriptionAdapter,
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            assetRepository: AnyDataProviderRepository(assetRepository),
            operationQueue: operationQueue
        )
        let router = SelectAssetRouter()

        let viewModelFactory = SelectAssetViewModelFactory(
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let presenter = SelectAssetPresenter(
            viewModelFactory: viewModelFactory,
            wallet: wallet,
            selectedAssetId: selectedAssetId,
            searchTextsViewModel: searchTextsViewModel,
            interactor: interactor,
            router: router,
            output: output,
            localizationManager: localizationManager
        )

        let view = SelectAssetViewController(
            output: presenter,
            localizationManager: localizationManager
        )
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
