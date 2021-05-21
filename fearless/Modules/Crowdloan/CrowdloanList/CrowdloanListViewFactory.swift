import Foundation
import SoraFoundation
import FearlessUtils
import SoraKeystore

struct CrowdloanListViewFactory {
    static func createView() -> CrowdloanListViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = CrowdloanListWireframe()

        let presenter = CrowdloanListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            logger: Logger.shared
        )

        let view = CrowdloanListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }

    private static func createInteractor() -> CrowdloanListInteractor? {
        guard let connection = WebSocketService.shared.connection else {
            return nil
        }

        let settings = SettingsManager.shared
        let chain = settings.selectedConnection.type.chain
        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        let singleValueProvider: AnySingleValueProvider<CrowdloanDisplayInfoList> =
            SingleValueProviderFactory.shared.getJson(for: chain.crowdloanDisplayInfoURL())

        return CrowdloanListInteractor(
            runtimeService: runtimeService,
            requestOperationFactory: storageRequestFactory,
            connection: connection,
            displayInfoProvider: singleValueProvider,
            operationManager: operationManager,
            logger: Logger.shared
        )
    }
}
