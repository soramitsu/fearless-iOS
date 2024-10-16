import UIKit
import WalletConnectSign
import SoraFoundation
import SoraUI
import RobinHood
import SSFNetwork
import SoraKeystore

enum WalletConnectSessionAssembly {
    static func configureModule(
        request: Request,
        session: Session?,
        onGoToConfirmation: ((WalletConnectConfirmationInputData) -> Void)?
    ) -> WalletConnectSessionModuleCreationResult? {
        let localizationManager = LocalizationManager.shared
        let logger = Logger.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let accountRepository = accountRepositoryFactory.createMetaAccountRepository(for: nil, sortDescriptors: [])

        let chainRepository = ChainRepositoryFactory().createRepository(
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter.shared

        let accountScoreFetcher = NomisAccountStatisticsFetcher(networkWorker: NetworkWorkerImpl(), signer: NomisRequestSigner())
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
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory(),
            accountScoreFetcher: accountScoreFetcher,
            settings: SettingsManager.shared
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
            configuration: ModalSheetPresentationConfiguration.fearlessBlur,
            shouldDissmissWhenTapOnBlurArea: false
        )
        view.modalTransitioningFactory = factory

        return (view, presenter)
    }
}
