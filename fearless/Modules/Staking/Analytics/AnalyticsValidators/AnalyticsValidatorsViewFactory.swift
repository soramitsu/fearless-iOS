import Foundation
import SoraFoundation
import SoraKeystore
import RobinHood
import FearlessUtils

struct AnalyticsValidatorsViewFactory {
    static func createView() -> AnalyticsValidatorsViewProtocol? {
        let settings = SettingsManager.shared
        let logger = Logger.shared
        let operationManager = OperationManagerFacade.sharedManager

        let chain = settings.selectedConnection.type.chain
        guard let engine = WebSocketService.shared.connection else { return nil }

        let requestFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: requestFactory)

        let interactor = AnalyticsValidatorsInteractor(
            identityOperationFactory: identityOperationFactory,
            operationManager: operationManager,
            engine: engine,
            runtimeService: RuntimeRegistryFacade.sharedService,
            chain: chain
        )

        let wireframe = AnalyticsValidatorsWireframe()
        let viewModelFactory = AnalyticsValidatorsViewModelFactory()
        let presenter = AnalyticsValidatorsPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            logger: logger
        )

        let view = AnalyticsValidatorsViewController(presenter: presenter)

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
