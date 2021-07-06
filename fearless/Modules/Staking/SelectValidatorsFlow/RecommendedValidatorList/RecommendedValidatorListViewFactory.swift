import Foundation
import SoraFoundation
import FearlessUtils

final class RecommendedValidatorListViewFactory: RecommendedValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingRecommendationWireframe(state: state)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeTargetsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsRecommendationWireframe(state: state)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createChangeYourValidatorsView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.RecommendationWireframe(state: state)
        return createView(for: validators, maxTargets: maxTargets, with: wireframe)
    }

    static func createView(
        for validators: [SelectedValidatorInfo],
        maxTargets: Int,
        with wireframe: RecommendedValidatorListWireframeProtocol
    ) -> RecommendedValidatorListViewProtocol? {
        let view = RecommendedValidatorListViewController(nib: R.nib.recommendedValidatorListViewController)

        let viewModelFactory = RecommendedValidatorListViewModelFactory(
            iconGenerator: PolkadotIconGenerator()
        )

        let presenter = RecommendedValidatorListPresenter(
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
