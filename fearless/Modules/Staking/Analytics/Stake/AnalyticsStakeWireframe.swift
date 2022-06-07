import Foundation

final class AnalyticsStakeWireframe: AnalyticsStakeWireframeProtocol {
    func showRewardDetails(
        _ rewardModel: AnalyticsRewardDetailsModel,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel
    ) {
        guard let rewardDetailsView = AnalyticsRewardDetailsViewFactory.createView(
            rewardModel: rewardModel,
            wallet: wallet
        )
        else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardDetailsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
