import Foundation
import SoraFoundation
import SoraKeystore

enum CustomValidatorListViewFactory {
    private static func createView(
        asset: AssetModel,
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        with wireframe: CustomValidatorListWireframeProtocol
    ) -> CustomValidatorListViewProtocol? {
        let priceLocalSubscriptionFactory = PriceProviderFactory(
            storageFacade: SubstrateDataStorageFacade.shared
        )

        let interactor = CustomValidatorListInteractor(
            priceLocalSubscriptionFactory: priceLocalSubscriptionFactory,
            asset: asset
        )

        let balanceViewModelFactory = BalanceViewModelFactory(targetAssetInfo: asset.displayInfo)

        let viewModelFactory = CustomValidatorListViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory
        )

        let presenter = CustomValidatorListPresenter(
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            fullValidatorList: validatorList,
            recommendedValidatorList: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            logger: Logger.shared
        )

        let view = CustomValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: maxTargets,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}

extension CustomValidatorListViewFactory {
    static func createInitiatedBondingView(
        asset: AssetModel,
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitBondingCustomValidatorListWireframe(state: state)
        return createView(
            asset: asset,
            for: validatorList,
            with: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        asset: AssetModel,
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe(state: state)
        return createView(
            asset: asset,
            for: validatorList,
            with: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        asset: AssetModel,
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe(state: state)
        return createView(
            asset: asset,
            for: validatorList,
            with: recommendedValidatorList,
            selectedValidatorList: selectedValidatorList,
            maxTargets: maxTargets,
            with: wireframe
        )
    }
}
