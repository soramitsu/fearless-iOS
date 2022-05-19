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

        guard let container = createContainer(flow: flow, chainAsset: chainAsset) else {
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
    static func createContainer(flow: CustomValidatorListFlow, chainAsset: ChainAsset) -> CustomValidatorListDependencyContainer? {
        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: chainAsset.asset.displayInfo)

        switch flow {
        case .parachain:
            let viewModelState = CustomValidatorListParachainViewModelState()
            let strategy = CustomValidatorListParachainStrategy()
            let viewModelFactory = CustomValidatorListParachainViewModelFactory()

            return CustomValidatorListDependencyContainer(
                viewModelState: viewModelState,
                strategy: strategy,
                viewModelFactory: viewModelFactory
            )
        case let .relaychain(validatorList, recommendedValidatorList, selectedValidatorList, maxTargets):
            let viewModelState = CustomValidatorListRelaychainViewModelState(
                fullValidatorList: validatorList,
                recommendedValidatorList: recommendedValidatorList,
                selectedValidatorList: selectedValidatorList,
                maxTargets: maxTargets
            )
            let strategy = CustomValidatorListRelaychainStrategy()
            let viewModelFactory = CustomValidatorListRelaychainViewModelFactory(balanceViewModelFactory: balanceViewModelFactory)

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
        flow: CustomValidatorListFlow,
        with state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitBondingCustomValidatorListWireframe(state: state)
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
        flow: CustomValidatorListFlow,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe(state: state)
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
        flow: CustomValidatorListFlow,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe(state: state)
        return createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: flow,
            with: wireframe
        )
    }
}
