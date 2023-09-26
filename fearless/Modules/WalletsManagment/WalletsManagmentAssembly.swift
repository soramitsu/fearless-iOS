import UIKit
import SoraFoundation
import RobinHood
import SoraUI
import SSFNetwork

final class WalletsManagmentAssembly {
    static func configureModule(
        viewType: WalletsManagmentType = .wallets,
        shouldSaveSelected: Bool,
        contextTag: Int = 0,
        moduleOutput: WalletsManagmentModuleOutput?
    ) -> WalletsManagmentModuleCreationResult? {
        guard let wallet = SelectedWalletSettings.shared.value else { return nil }
        let sharedDefaultQueue = OperationManagerFacade.sharedDefaultQueue
        let localizationManager = LocalizationManager.shared
        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])
        let managedMetaAccountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let substrateRepositoryFactory = SubstrateRepositoryFactory(
            storageFacade: UserDataStorageFacade.shared
        )

        let accountInfoRepository = substrateRepositoryFactory.createAccountInfoStorageItemRepository()

        let substrateAccountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: substrateAccountInfoFetching,
            operationQueue: sharedDefaultQueue,
            meta: wallet
        )

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter(
            metaAccountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAssetFetcher: chainAssetFetching,
            operationQueue: sharedDefaultQueue,
            eventCenter: eventCenter,
            logger: logger
        )

        let featureToggleProvider = FeatureToggleProvider(
            networkOperationFactory: NetworkOperationFactory(jsonDecoder: GithubJSONDecoder()),
            operationQueue: OperationQueue()
        )

        let interactor = WalletsManagmentInteractor(
            shouldSaveSelected: shouldSaveSelected,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            metaAccountRepository: AnyDataProviderRepository(managedMetaAccountRepository),
            operationQueue: sharedDefaultQueue,
            settings: SelectedWalletSettings.shared,
            eventCenter: eventCenter,
            featureToggleService: featureToggleProvider
        )
        let router = WalletsManagmentRouter()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = WalletsManagmentViewModelFactory(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let presenter = WalletsManagmentPresenter(
            viewType: viewType,
            contextTag: contextTag,
            viewModelFactory: viewModelFactory,
            logger: logger,
            interactor: interactor,
            router: router,
            moduleOutput: moduleOutput,
            localizationManager: localizationManager
        )

        let view = Self.createView(
            viewType: viewType,
            presenter: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }

    private static func createView(
        viewType: WalletsManagmentType,
        presenter: WalletsManagmentPresenter,
        localizationManager: LocalizationManager
    ) -> WalletsManagmentViewInput {
        let view = WalletsManagmentViewController(
            viewType: viewType,
            output: presenter,
            localizationManager: localizationManager
        )
        view.modalPresentationStyle = .custom

        let factory = ModalSheetBlurPresentationFactory(
            configuration: ModalSheetPresentationConfiguration.fearlessBlur
        )
        view.modalTransitioningFactory = factory

        return view
    }
}
