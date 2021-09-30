import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore
import IrohaCrypto
import RobinHood

struct CrowdloanListViewFactory {
    static func createView(with sharedState: CrowdloanSharedState) -> CrowdloanListViewProtocol? {
        guard let interactor = createInteractor(from: sharedState) else {
            return nil
        }

        let wireframe = CrowdloanListWireframe(state: sharedState)

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
        from state: CrowdloanSharedState
    ) -> CrowdloanListInteractor? {
        let selectedMetaAccount: MetaAccountModel = SelectedWalletSettings.shared.value

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
            walletLocalSubscriptionFactory: WalletLocalSubscriptionFactory.shared,
            jsonDataProviderFactory: JsonDataProviderFactory.shared,
            operationManager: operationManager,
            logger: logger
        )
    }
}
