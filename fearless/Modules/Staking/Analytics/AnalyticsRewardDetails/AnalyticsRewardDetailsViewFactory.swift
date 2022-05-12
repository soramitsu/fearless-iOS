import Foundation
import SoraFoundation
import SoraKeystore

struct AnalyticsRewardDetailsViewFactory {
    static func createView(
        rewardModel: AnalyticsRewardDetailsModel,
        wallet: MetaAccountModel
    ) -> AnalyticsRewardDetailsViewProtocol? {
        let interactor = AnalyticsRewardDetailsInteractor()
        let wireframe = AnalyticsRewardDetailsWireframe()

        let settings = SettingsManager.shared

        let addressType = settings.selectedConnection.type
        let chain = addressType.chain

        let targetAssetInfo = AssetBalanceDisplayInfo.forCurrency(wallet.selectedCurrency)
        let balanceViewModelFactory = BalanceViewModelFactory(
            targetAssetInfo: targetAssetInfo,
            limit: StakingConstants.maxAmount,
            selectedMetaAccount: wallet
        )

        let viewModelFactory = AnalyticsRewardDetailsViewModelFactory(
            chain: chain,
            balanceViewModelFactory: balanceViewModelFactory
        )
        let presenter = AnalyticsRewardDetailsPresenter(
            rewardModel: rewardModel,
            interactor: interactor,
            wireframe: wireframe,
            viewModelFactory: viewModelFactory,
            chain: chain
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
