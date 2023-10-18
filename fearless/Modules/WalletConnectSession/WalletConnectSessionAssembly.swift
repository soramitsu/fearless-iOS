import UIKit
import WalletConnectSign
import SoraFoundation
import SoraUI
import RobinHood

enum WalletConnectSessionAssembly {
    static func configureModule(
        request: Request,
        session: Session?,
        onGoToConfirmation: ((WalletConnectConfirmationInputData) -> Void)?
    ) -> WalletConnectSessionModuleCreationResult? {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return nil
        }

        let localizationManager = LocalizationManager.shared
        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

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

        let accountInfoFetching = AccountInfoFetching(
            accountInfoRepository: accountInfoRepository,
            chainRegistry: ChainRegistryFacade.sharedRegistry,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        let chainAssetFetching = ChainAssetsFetching(
            chainRepository: AnyDataProviderRepository(chainRepository),
            accountInfoFetching: accountInfoFetching,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            meta: wallet
        )

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter(
            metaAccountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAssetFetcher: chainAssetFetching,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            eventCenter: eventCenter,
            logger: logger
        )

        let interactor = WalletConnectSessionInteractor(
            walletConnect: WalletConnectServiceImpl.shared,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            walletRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )
        let router = WalletConnectSessionRouter(onGoToConfirmation: onGoToConfirmation)

        let walletConnectModelFactory = WalletConnectModelFactoryImpl()
        let walletConnectPayloaFactory = WalletConnectPayloadFactoryImpl()
        let viewModelFactory = WalletConnectSessionViewModelFactoryImpl(
            request: request,
            session: session,
            walletConnectModelFactory: walletConnectModelFactory,
            walletConnectPayloaFactory: walletConnectPayloaFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let presenter = WalletConnectSessionPresenter(
            request: request,
            session: session,
            viewModelFactory: viewModelFactory,
            walletConnectModelFactory: walletConnectModelFactory,
            logger: logger,
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = WalletConnectSessionViewController(
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
