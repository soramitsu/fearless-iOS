import UIKit
import WalletConnectSign
import SoraFoundation
import SoraUI
import RobinHood

enum WalletConnectSessionAssembly {
    static func configureModule(
        variant: ConnectRequestVariant,
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

        let interactor = WalletConnectSessionInteractor(
            walletConnect: WalletConnectServiceImpl.shared,
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            walletRepository: AnyDataProviderRepository(accountRepository),
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            tonConnectService: ServiceAssembly.shared.tonConnectService()
        )
        let router = WalletConnectSessionRouter(onGoToConfirmation: onGoToConfirmation)

        let walletConnectModelFactory = WalletConnectModelFactoryImpl()
        let walletConnectPayloaFactory = WalletConnectPayloadFactoryImpl()
        let viewModelFactory = WalletConnectSessionViewModelFactoryImpl(
            variant: variant,
            walletConnectModelFactory: walletConnectModelFactory,
            walletConnectPayloaFactory: walletConnectPayloaFactory,
            assetBalanceFormatterFactory: AssetBalanceFormatterFactory()
        )
        let presenter = WalletConnectSessionPresenter(
            variant: variant,
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
