import SoraFoundation

final class AnalyticsRewardsWireframe: AnalyticsRewardsWireframeProtocol {
    func showRewardDetails(_ rewardModel: AnalyticsRewardDetailsModel, from view: ControllerBackedProtocol?) {
        guard
            let rewardDetailsView = AnalyticsRewardDetailsViewFactory.createView(rewardModel: rewardModel)
        else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardDetailsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardPayoutsForNominator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForNominator(stashAddress: stashAddress) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardPayoutsForValidator(from view: ControllerBackedProtocol?, stashAddress: AccountAddress) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForValidator(stashAddress: stashAddress) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
