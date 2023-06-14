import Foundation
import SSFModels

final class AnalyticsStakeWireframe: AnalyticsStakeWireframeProtocol {
    func showRewardDetails(
        _ rewardModel: AnalyticsRewardDetailsModel,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard let rewardDetailsView = AnalyticsRewardDetailsViewFactory.createView(
            rewardModel: rewardModel,
            wallet: wallet,
            chainAsset: chainAsset
        )
        else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardDetailsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
