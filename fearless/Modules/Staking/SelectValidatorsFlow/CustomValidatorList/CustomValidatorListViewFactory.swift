import Foundation
import SoraFoundation
import SoraKeystore

enum CustomValidatorListViewFactory {
    private static func createView(
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        with wireframe: CustomValidatorListWireframeProtocol
    ) -> CustomValidatorListViewProtocol? {
        let settings = SettingsManager.shared
        let chain = settings.selectedConnection.type.chain
        let primitiveFactory = WalletPrimitiveFactory(settings: settings)

        let asset = primitiveFactory.createAssetForAddressType(
            chain.addressType
        )

        guard let assetId = WalletAssetId(rawValue: asset.identifier) else {
            return nil
        }

        let interactor = CustomValidatorListInteractor(
            singleValueProviderFactory: SingleValueProviderFactory.shared,
            assetId: assetId
        )

        let balanceViewModelFactory = BalanceViewModelFactory(
            walletPrimitiveFactory: primitiveFactory,
            selectedAddressType: chain.addressType,
            limit: StakingConstants.maxAmount
        )

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

extension CustomValidatorListViewFactory: CustomValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitBondingCustomValidatorListWireframe(state: state)
        return createView(
            for: validatorList,
            with: recommendedValidatorList,
            maxTargets: maxTargets,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe(state: state)
        return createView(
            for: validatorList,
            with: recommendedValidatorList,
            maxTargets: maxTargets,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        for validatorList: [SelectedValidatorInfo],
        with recommendedValidatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe(state: state)
        return createView(
            for: validatorList,
            with: recommendedValidatorList,
            maxTargets: maxTargets,
            with: wireframe
        )
    }
}
