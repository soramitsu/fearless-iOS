import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class RecommendedValidatorsViewFactory: RecommendedValidatorsViewFactoryProtocol {
    static func createInitiatedBondingView(with state: InitiatedBonding)
    -> RecommendedValidatorsViewProtocol? {
        let wireframe = InitiatedBondingRecommendationsWireframe(state: state)
        return createView(with: wireframe)
    }

    static func createChangeTargetsView(with state: ExistingBonding)
    -> RecommendedValidatorsViewProtocol? {
        let wireframe = ChangeTargetsRecommendationsWireframe(state: state)
        return createView(with: wireframe)
    }

    private static func createView(with wireframe: RecommendedValidatorsWireframeProtocol)
    -> RecommendedValidatorsViewProtocol? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let view = RecommendedValidatorsViewController(nib: R.nib.recommendedValidatorsViewController)
        let presenter = RecommendedValidatorsPresenter(logger: Logger.shared)

        let eraValidatorService = EraValidatorFacade.sharedService
        let runtimeService = RuntimeRegistryFacade.sharedService
        let storageOperationFactory = StorageRequestFactory(remoteFactory: StorageKeyFactory())
        let operationManager = OperationManagerFacade.sharedManager

        let chain = SettingsManager.shared.selectedConnection.type.chain

        let rewardService = RewardCalculatorFacade.sharedService
        let operationFactory = ValidatorOperationFactory(chain: chain,
                                                         eraValidatorService: eraValidatorService,
                                                         rewardService: rewardService,
                                                         storageRequestFactory: storageOperationFactory,
                                                         runtimeService: runtimeService,
                                                         engine: engine)

        let interactor = RecommendedValidatorsInteractor(operationFactory: operationFactory,
                                                         operationManager: operationManager)

        view.presenter = presenter
        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
