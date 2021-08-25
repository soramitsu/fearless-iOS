import SoraFoundation

final class AnalyticsRewardsWireframe: AnalyticsRewardsWireframeProtocol {
    func showRewardDetails(from view: ControllerBackedProtocol?) {
        guard let rewardDetailsView = AnalyticsRewardDetailsViewFactory.createView() else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardDetailsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showPendingRewards(from view: ControllerBackedProtocol?, stashAddress: AccountAddress) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory
            .createViewForNominator(stashAddress: stashAddress) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
