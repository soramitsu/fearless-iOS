import Foundation
import SoraFoundation
import FearlessUtils

struct CrowdloanListViewFactory {
    static func createView() -> CrowdloanListViewProtocol? {
        guard let interactor = createInteractor() else {
            return nil
        }

        let wireframe = CrowdloanListWireframe()

        let presenter = CrowdloanListPresenter(interactor: interactor, wireframe: wireframe)

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

        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager

        let storageRequestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )

        return CrowdloanListInteractor(
            runtimeService: runtimeService,
            requestOperationFactory: storageRequestFactory,
            connection: connection,
            operationManager: operationManager,
            logger: Logger.shared
        )
    }
}
