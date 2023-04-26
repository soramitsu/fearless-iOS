import Foundation
import SoraFoundation
import RobinHood
import SSFXCM

final class CrossChainConfirmationAssembly {
    static func configureModule(
        with data: CrossChainConfirmationData,
        xcmServices: XcmExtrinsicServices
    ) -> CrossChainConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let interactor = CrossChainConfirmationInteractor(
            teleportData: data,
            xcmServices: xcmServices,
            operationQueue: OperationManagerFacade.sharedDefaultQueue,
            logger: Logger.shared
        )
        let router = CrossChainConfirmationRouter()

        let presenter = CrossChainConfirmationPresenter(
            teleportData: data,
            viewModelFactory: CrossChainConfirmationViewModelFactory(),
            interactor: interactor,
            router: router,
            localizationManager: localizationManager
        )

        let view = CrossChainConfirmationViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
