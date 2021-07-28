import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class SelectValidatorsStartViewFactory: SelectValidatorsStartViewFactoryProtocol {
    static func createInitiatedBondingView(
        with state: InitiatedBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = InitBondingSelectValidatorsStartWireframe(state: state)
        return createView(with: wireframe, selectedValidators: nil)
    }

    static func createChangeTargetsView(
        with state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = ChangeTargetsSelectValidatorsStartWireframe(state: state)
        return createView(with: wireframe, selectedValidators: state.selectedTargets)
    }

    static func createChangeYourValidatorsView(
        with state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = YourValidatorList.SelectionStartWireframe(state: state)
        return createView(with: wireframe, selectedValidators: state.selectedTargets)
    }

    private static func createView(
        with wireframe: SelectValidatorsStartWireframeProtocol,
        selectedValidators: [SelectedValidatorInfo]?
    ) -> SelectValidatorsStartViewProtocol? {
        guard let engine = WebSocketService.shared.connection else {
            return nil
        }

        let eraValidatorService = EraValidatorFacade.sharedService
        let runtimeService = RuntimeRegistryFacade.sharedService
        let operationManager = OperationManagerFacade.sharedManager
        let storageOperationFactory = StorageRequestFactory(
            remoteFactory: StorageKeyFactory(),
            operationManager: operationManager
        )
        let identityOperationFactory = IdentityOperationFactory(requestFactory: storageOperationFactory)

        let chain = SettingsManager.shared.selectedConnection.type.chain

        let rewardService = RewardCalculatorFacade.sharedService
        let operationFactory = ValidatorOperationFactory(
            chain: chain,
            eraValidatorService: eraValidatorService,
            rewardService: rewardService,
            storageRequestFactory: storageOperationFactory,
            runtimeService: runtimeService,
            engine: engine,
            identityOperationFactory: identityOperationFactory
        )

        let interactor = SelectValidatorsStartInteractor(
            runtimeService: runtimeService,
            operationFactory: operationFactory,
            operationManager: operationManager
        )

        let presenter = SelectValidatorsStartPresenter(
            interactor: interactor,
            wireframe: wireframe,
            initialTargets: selectedValidators,
            logger: Logger.shared
        )

        let view = SelectValidatorsStartViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
