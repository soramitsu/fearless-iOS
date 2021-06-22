import Foundation
import SoraFoundation
import SoraKeystore

struct CustomValidatorListViewFactory: CustomValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        for electedValidators: [ElectedValidatorInfo],
        recommendedValidators: [ElectedValidatorInfo],
        maxTargets: Int,
        with state: InitiatedBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = InitiatedBondingCustomValidatorListWireframe(state: state)
        return createView(
            electedValidators: electedValidators,
            recommendedValidators: recommendedValidators,
            maxTargets: maxTargets,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        for electedValidators: [ElectedValidatorInfo],
        recommendedValidators: [ElectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = ChangeTargetsCustomValidatorListWireframe(state: state)
        return createView(
            electedValidators: electedValidators,
            recommendedValidators: recommendedValidators,
            maxTargets: maxTargets,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        for electedValidators: [ElectedValidatorInfo],
        recommendedValidators: [ElectedValidatorInfo],
        maxTargets: Int,
        with state: ExistingBonding
    ) -> CustomValidatorListViewProtocol? {
        let wireframe = YourValidatorList.CustomListWireframe(state: state)
        return createView(
            electedValidators: electedValidators,
            recommendedValidators: recommendedValidators,
            maxTargets: maxTargets,
            with: wireframe
        )
    }

    static func createView(
        electedValidators: [ElectedValidatorInfo],
        recommendedValidators: [ElectedValidatorInfo],
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
            electedValidators: electedValidators,
            recommendedValidators: recommendedValidators,
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
