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
        let sharedDefaultQueue = OperationManagerFacade.sharedDefaultQueue
        let localizationManager = LocalizationManager.shared
        let eventCenter = EventCenter.shared
        let logger = Logger.shared

        let accountRepositoryFactory = AccountRepositoryFactory(storageFacade: UserDataStorageFacade.shared)
        let managedMetaAccountRepository = accountRepositoryFactory.createManagedMetaAccountRepository(
            for: nil,
            sortDescriptors: []
        )

        let chainRepository = ChainRepositoryFactory().createRepository(
            for: NSPredicate.enabledCHain(),
            sortDescriptors: [NSSortDescriptor.chainsByAddressPrefix]
        )

        let walletBalanceSubscriptionAdapter = WalletBalanceSubscriptionAdapter.shared

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

        let accountScoreFetcher = NomisAccountStatisticsFetcher(
            networkWorker: NetworkWorkerImpl(),
            signer: NomisRequestSigner()
        )
        let assetBalanceFormatterFactory = AssetBalanceFormatterFactory()
        let viewModelFactory = WalletsManagmentViewModelFactory(
            assetBalanceFormatterFactory: assetBalanceFormatterFactory,
            accountScoreFetcher: accountScoreFetcher
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
