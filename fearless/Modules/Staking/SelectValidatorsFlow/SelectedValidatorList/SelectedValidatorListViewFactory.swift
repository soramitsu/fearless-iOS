import Foundation
import SoraFoundation

struct SelectedValidatorListViewFactory: SelectedValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        for validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        with state: InitiatedBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingSelectedValidatorListWireframe(state: state)
        return createView(
            validators: validators,
            maxTargets: maxTargets,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        for validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        with state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsSelectedValidatorListWireframe(state: state)
        return createView(
            validators: validators,
            maxTargets: maxTargets,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        for validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        with state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.SelectedListWireframe(state: state)
        return createView(
            validators: validators,
            maxTargets: maxTargets,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createView(
        validators: [ElectedValidatorInfo],
        maxTargets: Int,
        delegate: SelectedValidatorListDelegate,
        with wireframe: SelectedValidatorListWireframeProtocol
    ) -> SelectedValidatorListViewProtocol? {
        let viewModelFactory = SelectedValidatorListViewModelFactory()

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedValidators: validators,
            maxTargets: maxTargets
        )

        presenter.delegate = delegate

        let view = SelectedValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: maxTargets,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
