import Foundation
import SoraFoundation
import FearlessUtils

final class SelectedValidatorsViewFactory: SelectedValidatorsViewFactoryProtocol {
    static func createInitiatedBondingView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> SelectedValidatorsViewProtocol? {
        let wireframe = InitiatedBondingSelectionWireframe(state: state)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeTargetsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> SelectedValidatorsViewProtocol? {
        let wireframe = ChangeTargetsSelectionWireframe(state: state)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeYourValidatorsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> SelectedValidatorsViewProtocol? {
        let wireframe = YourValidators.SelectionWireframe(state: state)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with wireframe: SelectedValidatorsWireframeProtocol
    ) -> SelectedValidatorsViewProtocol? {
        let view = SelectedValidatorsViewController(nib: R.nib.selectedValidatorsViewController)

        let viewModelFactory = SelectedValidatorsViewModelFactory(
            iconGenerator: PolkadotIconGenerator()
        )

        let presenter = SelectedValidatorsPresenter(
            viewModelFactory: viewModelFactory,
            validators: validators,
            maxTargets: maxTargets,
            logger: Logger.shared
        )

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        view.localizationManager = LocalizationManager.shared

        return view
    }
}
