import Foundation
import FearlessUtils
import SoraKeystore
import SoraFoundation

final class SelectValidatorsStartViewFactory: SelectValidatorsStartViewFactoryProtocol {
    static func createInitiatedBondingView(
        asset: AssetModel,
        chain: ChainModel,
        with state: InitiatedBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = InitBondingSelectValidatorsStartWireframe(state: state)
        return createView(
            chain: chain,
            asset: asset,
            with: wireframe,
            existingStashAddress: nil,
            selectedValidators: nil
        )
    }

    static func createChangeTargetsView(
        asset: AssetModel,
        chain: ChainModel,
        with state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = ChangeTargetsSelectValidatorsStartWireframe(state: state)
        return createView(
            chain: chain,
            asset: asset,
            with: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets
        )
    }

    static func createChangeYourValidatorsView(
        asset: AssetModel,
        chain: ChainModel,
        with state: ExistingBonding
    ) -> SelectValidatorsStartViewProtocol? {
        let wireframe = YourValidatorList.SelectionStartWireframe(state: state)
        return createView(
            chain: chain,
            asset: asset,
            with: wireframe,
            existingStashAddress: state.stashAddress,
            selectedValidators: state.selectedTargets
        )
    }

    private static func createView(
        chain: ChainModel,
        asset: AssetModel,
        with wireframe: SelectValidatorsStartWireframeProtocol,
        existingStashAddress: AccountAddress?,
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

        let rewardService = RewardCalculatorFacade.sharedService
        let operationFactory = ValidatorOperationFactory(
            asset: asset,
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
            existingStashAddress: existingStashAddress,
            initialTargets: selectedValidators,
            logger: Logger.shared
        )

        let view = SelectValidatorsStartViewController(
            presenter: presenter,
            phase: selectedValidators == nil ? .setup : .update,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
