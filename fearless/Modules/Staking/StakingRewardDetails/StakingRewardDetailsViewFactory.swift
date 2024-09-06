import Foundation
import SoraFoundation
import SoraKeystore
import SSFUtils
import SSFModels

final class StakingRewardDetailsViewFactory: StakingRewardDetailsViewFactoryProtocol {
    static func createView(
        wallet: MetaAccountModel,
        chainAsset: ChainAsset,
        input: StakingRewardDetailsInput
    ) -> StakingRewardDetailsViewProtocol? {
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,
            selectedMetaAccount: wallet,
            chainAsset: chainAsset
        )

        let viewModelFactory = StakingRewardDetailsViewModelFactory(
            balanceViewModelFactory: balanceViewModelFactory,
            iconGenerator: UniversalIconGenerator()
        )

        let presenter = StakingRewardDetailsPresenter(
            chainAsset: chainAsset,
            wallet: wallet,
            input: input,
            viewModelFactory: viewModelFactory
        )
        let view = StakingRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        let interactor = StakingRewardDetailsInteractor(
            chainAsset: chainAsset
        )
        let wireframe = StakingRewardDetailsWireframe()

        presenter.view = view
        presenter.interactor = interactor
        presenter.wireframe = wireframe
        interactor.presenter = presenter

        return view
    }
}
