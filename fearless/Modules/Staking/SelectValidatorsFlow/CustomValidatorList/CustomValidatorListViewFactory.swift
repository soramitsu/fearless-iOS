import Foundation
import SoraFoundation
import SoraKeystore

enum CustomValidatorListViewFactory {
    private static func createView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: CustomValidatorListFlow,
        with wireframe: CustomValidatorListWireframeProtocol
    ) -> CustomValidatorListViewProtocol? {
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        guard let container = createContainer(flow: flow, chainAsset: chainAsset, wallet: wallet) else {
            return nil
        }

        let interactor = CustomValidatorListInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            asset: chainAsset.asset
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
            selectedValidatorsLimit: 0,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

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
        let iconGenerator = UniversalIconGenerator(chain: chainAsset.chain)

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
        case let .relaychainInitiated(validatorList, recommendedValidatorList, selectedValidatorList, maxTargets, bonding):
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
        case let .relaychainExisting(validatorList, recommendedValidatorList, selectedValidatorList, maxTargets, bonding):
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

    static func createInitiatedBondingView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: CustomValidatorListFlow
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitBondingCustomValidatorListWireframe()
        return createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: CustomValidatorListFlow
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe()
        return createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        flow: CustomValidatorListFlow
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe()
        return createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            with: wireframe
        )
    }
}
