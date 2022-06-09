import Foundation
import SoraFoundation

struct SelectedValidatorListViewFactory: SelectedValidatorListViewFactoryProtocol {
    private static func createContainer(flow: SelectedValidatorListFlow, delegate: SelectedValidatorListDelegate) -> SelectedValidatorListDependencyContainer? {
        switch flow {
        case let .relaychainInitiated(validatorList, maxTargets, _):
            let viewModelState = SelectedValidatorListRelaychainViewModelState(
                baseFlow: flow,
                maxTargets: maxTargets,
                selectedValidatorList: validatorList,
                delegate: delegate
            )
            let viewModelFactory = SelectedValidatorListRelaychainViewModelFactory()
            return SelectedValidatorListDependencyContainer(
                viewModelState: viewModelState,
                viewModelFactory: viewModelFactory
            )
        case let .relaychainExisting(validatorList, maxTargets, _):
            let viewModelState = SelectedValidatorListRelaychainViewModelState(
                baseFlow: flow,
                maxTargets: maxTargets,
                selectedValidatorList: validatorList,
                delegate: delegate
            )
            let viewModelFactory = SelectedValidatorListRelaychainViewModelFactory()
            return SelectedValidatorListDependencyContainer(
                viewModelState: viewModelState,
                viewModelFactory: viewModelFactory
            )
        case let .parachain(collators, maxTargets, state):
            let viewModelState = SelectedValidatorListParachainViewModelState(
                baseFlow: flow,
                maxTargets: maxTargets,
                selectedValidatorList: collators,
                delegate: delegate,
                bonding: state
            )
            let viewModelFactory = SelectedValidatorListParachainViewModelFactory()
            return SelectedValidatorListDependencyContainer(viewModelState: viewModelState, viewModelFactory: viewModelFactory)
        }
    }

    static func createInitiatedBondingView(
        flow: SelectedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        delegate: SelectedValidatorListDelegate
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingSelectedValidatorListWireframe()
        return createView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        flow: SelectedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        delegate: SelectedValidatorListDelegate
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsSelectedValidatorListWireframe()
        return createView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        flow: SelectedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        delegate: SelectedValidatorListDelegate
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.SelectedListWireframe()
        return createView(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createView(
        flow: SelectedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        delegate: SelectedValidatorListDelegate,
        with wireframe: SelectedValidatorListWireframeProtocol
    ) -> SelectedValidatorListViewProtocol? {
        guard let container = createContainer(flow: flow, delegate: delegate) else {
            return nil
        }

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            localizationManager: LocalizationManager.shared,
            chainAsset: chainAsset,
            wallet: wallet
        )

        let view = SelectedValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
