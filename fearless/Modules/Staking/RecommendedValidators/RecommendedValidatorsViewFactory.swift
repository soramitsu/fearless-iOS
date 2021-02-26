import Foundation
import FearlessUtils

final class RecommendedValidatorsViewFactory: RecommendedValidatorsViewFactoryProtocol {
    static func createView(with stakingState: StartStakingResult) -> RecommendedValidatorsViewProtocol? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let view = RecommendedValidatorsViewController(nib: R.nib.recommendedValidatorsViewController)
        let presenter = RecommendedValidatorsPresenter()

        let eraValidatorService = EraValidatorFacade.sharedService
        let runtimeService = RuntimeRegistryFacade.sharedService
        let storageOperationFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())
        let operationManager = OperationManagerFacade.sharedManager

        let interactor = RecommendedValidatorsInteractor(eraValidatorService: eraValidatorService,
                                                         storageRequestFactory: storageOperationFactory,
                                                         runtimeService: runtimeService,
                                                         engine: engine,
                                                         operationManager: operationManager,
                                                         logger: Logger.shared)
        let wireframe = RecommendedValidatorsWireframe()

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
