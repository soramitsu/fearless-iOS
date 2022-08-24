import UIKit
import SoraFoundation
import RobinHood
import SoraUI

final class WalletsManagmentAssembly {
    static func configureModule(
        moduleOutput: WalletsManagmentModuleOutput?
    ) -> WalletsManagmentModuleCreationResult? {
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

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter(
            metaAccountRepository: AnyDataProviderRepository(accountRepository),
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainRepository: AnyDataProviderRepository(chainRepository),
            operationQueue: sharedDefaultQueue,
            eventCenter: eventCenter,
            logger: logger
        )

        let interactor = WalletsManagmentInteractor(
            walletBalanceSubscriptionAdapter: walletBalanceSubscriptionAdapter,
            metaAccountRepository: AnyDataProviderRepository(managedMetaAccountRepository),
            operationQueue: sharedDefaultQueue,
            settings: SelectedWalletSettings.shared,
            eventCenter: eventCenter
        )
        let router = WalletsManagmentRouter()

        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = WalletsManagmentViewModelFactory(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory
        )

        let presenter = WalletsManagmentPresenter(
            viewModelFactory: viewModelFactory,
            logger: logger,
            interactor: interactor,
            router: router,
            moduleOutput: moduleOutput,
            localizationManager: localizationManager
        )

        let view = Self.createView(presenter: presenter, localizationManager: localizationManager)

        return (view, presenter)
    }

    private static func createView(
        presenter: WalletsManagmentPresenter,
        localizationManager: LocalizationManager
    ) -> WalletsManagmentViewInput {
        let view = WalletsManagmentViewController(
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
