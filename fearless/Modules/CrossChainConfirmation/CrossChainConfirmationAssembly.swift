import Foundation
import SoraFoundation
import RobinHood
import SSFXCM
import SSFNetwork

final class CrossChainConfirmationAssembly {
    static func configureModule(
        with data: CrossChainConfirmationData,
        xcmServices _: XcmExtrinsicServices
    ) -> CrossChainConfirmationModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        // The setup screen may use the shared cached estimator for previews.
        // Confirmation uses a no-cache provider and repeats the exact fee read
        // in both authorization passes.
        let destinationFeeProvider = XcmDestinationFeeFetcher(
            sourceUrl: ApplicationConfig.shared.destinationFeeSourceUrl,
            networkOperationFactory: NetworkOperationFactory(),
            operationQueue: OperationQueue(),
            useCache: false
        )
        let submissionAuthorizer = ReviewedCrossChainSubmissionAuthorizer(
            data: data,
            destinationFeeProvider: destinationFeeProvider
        )

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
