import Foundation
import SoraFoundation
import SoraKeystore

struct AnalyticsRewardDetailsViewFactory {
    static func createView(
        rewardModel: AnalyticsRewardDetailsModel,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) -> AnalyticsRewardDetailsViewProtocol? {
        let interactor = AnalyticsRewardDetailsInteractor()
        let wireframe = AnalyticsRewardDetailsWireframe()

        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: chainAsset.asset.displayInfo,

            selectedMetaAccount: wallet
        )

        let viewModelFactory = AnalyticsRewardDetailsViewModelFactory(
            chainAsset: chainAsset,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let presenter = AnalyticsRewardDetailsPresenter(
            rewardModel: rewardModel,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chainAsset: chainAsset
        )

        let view = AnalyticsRewardDetailsViewController(
            presenter: presenter,
            localizationManager: LocalizationManager.shared
        )

        presenter.view = view
        interactor.presenter = presenter

        return view
    }
}
