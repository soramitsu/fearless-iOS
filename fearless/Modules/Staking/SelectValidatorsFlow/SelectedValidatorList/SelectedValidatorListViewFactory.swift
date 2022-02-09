import Foundation
import SoraFoundation

struct SelectedValidatorListViewFactory: SelectedValidatorListViewFactoryProtocol {
    static func createInitiatedBondingView(
        for validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        delegate: SelectedValidatorListDelegate,
        with state: InitiatedBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = InitiatedBondingSelectedValidatorListWireframe(state: state)
        return createView(
            validatorList: validatorList,
            maxTargets: maxTargets,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createChangeTargetsView(
        for validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        delegate: SelectedValidatorListDelegate,
        with state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = ChangeTargetsSelectedValidatorListWireframe(state: state)
        return createView(
            validatorList: validatorList,
            maxTargets: maxTargets,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createChangeYourValidatorsView(
        for validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        delegate: SelectedValidatorListDelegate,
        with state: ExistingBonding
    ) -> SelectedValidatorListViewProtocol? {
        let wireframe = YourValidatorList.SelectedListWireframe(state: state)
        return createView(
            validatorList: validatorList,
            maxTargets: maxTargets,
            chain: chain,
            asset: asset,
            selectedAccount: selectedAccount,
            delegate: delegate,
            with: wireframe
        )
    }

    static func createView(
        validatorList: [SelectedValidatorInfo],
        maxTargets: Int,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        delegate: SelectedValidatorListDelegate,
        with wireframe: SelectedValidatorListWireframeProtocol
    ) -> SelectedValidatorListViewProtocol? {
        let viewModelFactory = SelectedValidatorListViewModelFactory()

        let presenter = SelectedValidatorListPresenter(
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            localizationManager: LocalizationManager.shared,
            selectedValidatorList: validatorList,
            maxTargets: maxTargets,
            asset: asset,
            chain: chain,
            selectedAccount: selectedAccount
        )

        presenter.delegate = delegate

        let view = SelectedValidatorListViewController(
            presenter: presenter,
            selectedValidatorsLimit: maxTargets,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view

        return view
    }
}
