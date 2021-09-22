import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore
import IrohaCrypto
import RobinHood

struct CrowdloanListViewFactory {
    static func createView() -> CrowdloanListViewProtocol? {
        let settings = SettingsManager.shared

        let crowdloanSettings = CrowdloanChainSettings(
            storageFacade: SubstrateDataStorageFacade.shared,
            settings: settings,
            operationQueue: OperationManagerFacade.sharedDefaultQueue
        )

        crowdloanSettings.setup()

        guard let interactor = createInteractor(from: crowdloanSettings) else {
            return nil
        }

        let wireframe = CrowdloanListWireframe()

        let localizationManager = LocalizationManager.shared

        let viewModelFactory = CrowdloansViewModelFactory(
            amountFormatterFactory: AssetBalanceFormatterFactory()
        )

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: localizationManager,
            logger: Logger.shared
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
        from settings: CrowdloanChainSettings
    ) -> CrowdloanListInteractor? {
        let selectedMetaAccount: MetaAccountModel = SelectedWalletSettings.shared.value

        let chainRegistry = ChainRegistryFacade.sharedRegistry
        let storageFacade = SubstrateDataStorageFacade.shared
        let repository = SubstrateRepositoryFactory().createChainStorageItemRepository()

        let operationManager = OperationManagerFacade.sharedManager
        let logger = Logger.shared

        let remoteSubscriptionService = CrowdloanRemoteSubscriptionService(
            chainRegistry: chainRegistry,
            repository: AnyDataProviderRepository(repository),
            operationManager: operationManager,
            logger: logger
        )

        let localSubscriptionFactory = CrowdloanLocalSubscriptionFactory(
            chainRegistry: chainRegistry,
            storageFacade: storageFacade,
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
            settings: settings,
            chainRegistry: chainRegistry,
            crowdloanOperationFactory: crowdloanOperationFactory,
            localSubscriptionFactory: localSubscriptionFactory,
            crowdloanRemoteSubscriptionService: remoteSubscriptionService,
            jsonDataProviderFactory: JsonDataProviderFactory.shared,
            operationManager: operationManager
        )
    }
}
