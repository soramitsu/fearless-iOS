import Foundation

final class AnalyticsStakeWireframe: AnalyticsStakeWireframeProtocol {
    func showRewardDetails(_ rewardModel: AnalyticsRewardDetailsModel, from view: ControllerBackedProtocol?) {
        guard
            let rewardDetailsView = AnalyticsRewardDetailsViewFactory.createView(rewardModel: rewardModel)
        else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardDetailsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
