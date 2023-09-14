import Foundation
import SoraFoundation
import SSFModels
import SSFUtils

// swiftlint:disable function_body_length
struct SelectedValidatorListViewFactory: SelectedValidatorListViewFactoryProtocol {
    private static func createContainer(
        flow: SelectedValidatorListFlow,
        delegate: SelectedValidatorListDelegate,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> SelectedValidatorListDependencyContainer? {
        let iconGenerator = UniversalIconGenerator()
        let balanceViewModelFactory: BalanceViewModelFactoryProtocol = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.assetDisplayInfo,
            selectedMetaAccount: wallet
        )

        switch flow {
        case let .relaychainInitiated(validatorList, maxTargets, _):
            let viewModelState = SelectedValidatorListRelaychainViewModelState(
                baseFlow: flow,
                maxTargets: maxTargets,
                selectedValidatorList: validatorList,
                delegate: delegate
            )
            let viewModelFactory = SelectedValidatorListRelaychainViewModelFactory(
                iconGenerator: iconGenerator,
                balanceViewModelFactory: balanceViewModelFactory
            )
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
            let viewModelFactory = SelectedValidatorListRelaychainViewModelFactory(
                iconGenerator: iconGenerator,
                balanceViewModelFactory: balanceViewModelFactory
            )
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
            let viewModelFactory = SelectedValidatorListParachainViewModelFactory(
                iconGenerator: iconGenerator,
                chainAsset: chainAsset,
                balanceViewModelFactory: balanceViewModelFactory
            )
            return SelectedValidatorListDependencyContainer(
                viewModelState: viewModelState,
                viewModelFactory: viewModelFactory
            )
        case let .poolInitiated(validatorList, _, maxTargets, _):
            let viewModelState = SelectedValidatorListRelaychainViewModelState(
                baseFlow: flow,
                maxTargets: maxTargets,
                selectedValidatorList: validatorList,
                delegate: delegate
            )
            let viewModelFactory = SelectedValidatorListRelaychainViewModelFactory(
                iconGenerator: iconGenerator,
                balanceViewModelFactory: balanceViewModelFactory
            )
            return SelectedValidatorListDependencyContainer(
                viewModelState: viewModelState,
                viewModelFactory: viewModelFactory
            )
        case let .poolExisting(validatorList, _, maxTargets, _):
            let viewModelState = SelectedValidatorListRelaychainViewModelState(
                baseFlow: flow,
                maxTargets: maxTargets,
                selectedValidatorList: validatorList,
                delegate: delegate
            )
            let viewModelFactory = SelectedValidatorListRelaychainViewModelFactory(
                iconGenerator: iconGenerator,
                balanceViewModelFactory: balanceViewModelFactory
            )
            return SelectedValidatorListDependencyContainer(
                viewModelState: viewModelState,
                viewModelFactory: viewModelFactory
            )
        }
    }

    static func createView(
        flow: SelectedValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        delegate: SelectedValidatorListDelegate
    ) -> SelectedValidatorListViewProtocol? {
        guard let container = createContainer(
            flow: flow,
            delegate: delegate,
            chainAsset: chainAsset,
            wallet: wallet
        ) else {
            return nil
        }

        let wireframe = SelectedValidatorListWireframe()

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
