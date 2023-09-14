import Foundation
import SoraFoundation
import SSFUtils
import SoraKeystore
import IrohaCrypto
import SSFModels
import RobinHood

struct CrowdloanListViewFactory {
    static func createView(
        with sharedState: CrowdloanSharedState,
        selectedMetaAccount: MetaAccountModel
    ) -> CrowdloanListViewProtocol? {
        guard let interactor = createInteractor(
            from: sharedState,
            with: selectedMetaAccount
        ) else {
            return nil
        }

        let wireframe = CrowdloanListWireframe(state: sharedState)

        let localizationManager = LocalizationManager.shared

        var iconGenerator: IconGenerating?
        if let chain = sharedState.settings.value {
            iconGenerator = UniversalIconGenerator()
        }

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory(),
            iconGenerator: iconGenerator
        )

        let config: ApplicationConfigProtocol = ApplicationConfig.shared

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared,
            crowdloanWiki: config.crowdloanWiki
        )

        let view = CrowdloanListViewController(
            presenter: presenter,
            localizationManager: localizationManager
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor(
        from state: CrowdloanSharedState,
        with selectedMetaAccount: MetaAccountModel
    ) -> CrowdloanListInteractor? {
        let selectedMetaAccount: MetaAccountModel = selectedMetaAccount

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()

        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let crowdloanRemoteSubscriptionService = CrowdloanRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: AnyDataProviderRepository(repository),
            operationManager: operationManager,
            logger: logger
        )

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let crowdloanOperationFactory = CrowdloanOperationFactory(
            requestOperationFactory: storageRequestFactory,
            operationManager: operationManager
        )

        return CrowdloanListInteractor(
            selectedMetaAccount: selectedMetaAccount,
            settings: state.settings,
            chainRegistry: chainRegistry,
            crowdloanOperationFactory: crowdloanOperationFactory,
            crowdloanRemoteSubscriptionService: crowdloanRemoteSubscriptionService,
            crowdloanLocalSubscriptionFactory: state.crowdloanLocalSubscriptionFactory,
            accountInfoSubscriptionAdapter: AccountInfoSubscriptionAdapter(
                walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
                selectedMetaAccount: selectedMetaAccount
            ),
            jsonDataProviderFactory: JsonDataProviderFactory.shared,
            operationManager: operationManager,
            logger: logger,
            eventCenter: EventCenter.shared
        )
    }
}
