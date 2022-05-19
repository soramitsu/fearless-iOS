import Foundation
import SoraFoundation
import FearlessUtils

final class RecommendedValidatorListViewFactory: RecommendedValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        with state: InitiatedBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingRecommendationWireframe(state: state)
        return createView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsRecommendationWireframe(state: state)
        return createView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        flow: RecommendedValidatorListFlow,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        with state: ExistingBonding
    ) -> RecommendedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.RecommendationWireframe(state: state)
        return createView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            with: wireframe
        )
    }

    static func createView(
        flow: RecommendedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        with wireframe: RecommendedValidatorListWireframeProtocol
    ) -> RecommendedValidatorListViewProtocol? {
        guard let container = createContainer(flow: flow) else {
            return nil
        }

        let view = RecommendedValidatorListViewController(nib: R.nib.recommendedValidatorListViewController)

        let presenter = RecommendedValidatorListPresenter(
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            logger: Logger.shared,
            chainAsset: chainAsset,
            wallet: wallet
        )

        view.presenter = presenter
        presenter.view = view
        presenter.wireframe = wireframe

        view.localizationManager = LocalizationManager.shared

        return view
    }

    static func createContainer(flow: RecommendedValidatorListFlow) -> RecommendedValidatorListDependencyContainer? {
        switch flow {
        case let .relaychain(validators, maxTargets):
            let viewModelState = RecommendedValidatorListRelaychainViewModelState(validators: validators, maxTargets: maxTargets)
            let strategy = RecommendedValidatorListRelaychainStrategy()
            let viewModelFactory = RecommendedValidatorListRelaychainViewModelFactory(iconGenerator: PolkadotIconGenerator())
            return RecommendedValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case .parachain:
            let viewModelState = RecommendedValidatorListParachainViewModelState()
            let strategy = RecommendedValidatorListParachainStrategy()
            let viewModelFactory = RecommendedValidatorListParachainViewModelFactory(iconGenerator: PolkadotIconGenerator())
            return RecommendedValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
