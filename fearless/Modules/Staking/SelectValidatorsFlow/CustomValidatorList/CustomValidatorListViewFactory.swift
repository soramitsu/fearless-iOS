import Foundation
import SoraFoundation
import SoraKeystore
import SSFModels
import SSFUtils

enum CustomValidatorListViewFactory {
    static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: CustomValidatorListFlow
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = CustomValidatorListWireframe()
        let priceLocalSubscriptionFactory = PriceProviderFactory.shared

        guard let container = createContainer(
            flow: flow,
            chainAsset: chainAsset,
            wallet: wallet
        ) else {
            return nil
        }

        let interactor = CustomValidatorListInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            chainAsset: chainAsset
        )

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: container.viewModelFactory,
            viewModelState: container.viewModelState,
            localizationManager: LocalizationManager.shared,
            chainAsset: chainAsset,
            wallet: wallet
        )

        let view = CustomValidatorListViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

// swiftlint:disable function_body_length
extension CustomValidatorListViewFactory {
    static func createContainer(
        flow: CustomValidatorListFlow,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) -> CustomValidatorListDependencyContainer? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet
        )
        let iconGenerator = UniversalIconGenerator()

        switch flow {
        case let .parachain(candidates, maxTargets, bonding, selectedValidatorList):
            let viewModelState = CustomValidatorListParachainViewModelState(
                candidates: candidates,
                maxTargets: maxTargets,
                bonding: bonding,
                selectedValidatorList: selectedValidatorList,
                chainAsset: chainAsset
            )
            let strategy = CustomValidatorListParachainStrategy()
            let viewModelFactory = CustomValidatorListParachainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                chainAsset: chainAsset,
                iconGenerator: iconGenerator
            )

            return CustomValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .relaychainInitiated(
            validatorList,
            recommendedValidatorList,
            selectedValidatorList,
            maxTargets,
            _
        ):
            let viewModelState = CustomValidatorListRelaychainViewModelState(
                baseFlow: flow,
                fullValidatorList: validatorList,
                recommendedValidatorList: recommendedValidatorList,
                selectedValidatorList: selectedValidatorList,
                maxTargets: maxTargets
            )
            let strategy = CustomValidatorListRelaychainStrategy()
            let viewModelFactory = CustomValidatorListRelaychainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator
            )

            return CustomValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .relaychainExisting(
            validatorList,
            recommendedValidatorList,
            selectedValidatorList,
            maxTargets,
            _
        ):
            let viewModelState = CustomValidatorListRelaychainViewModelState(
                baseFlow: flow,
                fullValidatorList: validatorList,
                recommendedValidatorList: recommendedValidatorList,
                selectedValidatorList: selectedValidatorList,
                maxTargets: maxTargets
            )
            let strategy = CustomValidatorListRelaychainStrategy()
            let viewModelFactory = CustomValidatorListRelaychainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator
            )

            return CustomValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .poolExisting(
            validatorList,
            recommendedValidatorList,
            selectedValidatorList,
            _,
            maxTargets,
            _
        ):
            let viewModelState = CustomValidatorListRelaychainViewModelState(
                baseFlow: flow,
                fullValidatorList: validatorList,
                recommendedValidatorList: recommendedValidatorList,
                selectedValidatorList: selectedValidatorList,
                maxTargets: maxTargets
            )
            let strategy = CustomValidatorListRelaychainStrategy()
            let viewModelFactory = CustomValidatorListRelaychainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator
            )

            return CustomValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .poolInitiated(
            validatorList,
            recommendedValidatorList,
            selectedValidatorList,
            _,
            maxTargets,
            _
        ):
            let viewModelState = CustomValidatorListRelaychainViewModelState(
                baseFlow: flow,
                fullValidatorList: validatorList,
                recommendedValidatorList: recommendedValidatorList,
                selectedValidatorList: selectedValidatorList,
                maxTargets: maxTargets
            )
            let strategy = CustomValidatorListRelaychainStrategy()
            let viewModelFactory = CustomValidatorListRelaychainViewModelFactory(
                balanceViewModelFactory: balanceViewModelFactory,
                iconGenerator: iconGenerator
            )

            return CustomValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        }
    }
}
