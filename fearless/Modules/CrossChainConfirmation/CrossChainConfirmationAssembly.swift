import Foundation
import SoraFoundation
import RobinHood
import SSFXCM
import SSFNetwork

final class CrossChainConfirmationAssembly {
    static func configureModule(
        with data: CrossChainConfirmationData
    ) -> CrossChainConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        // Both authorization passes use the destination fee compiled with the reviewed route.
        let submissionAuthorizer = ReviewedCrossChainSubmissionAuthorizer(data: data)

        let interactor = CrossChainConfirmationInteractor(
            teleportData: data,
            submissionAuthorizer: submissionAuthorizer,
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
