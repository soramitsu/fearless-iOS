import SoraFoundation
import SSFModels

final class AnalyticsRewardsWireframe: AnalyticsRewardsWireframeProtocol {
    func showRewardDetails(
        _ rewardModel: AnalyticsRewardDetailsModel,
        from view: ControllerBackedProtocol?,
        wallet: MetaAccountModel,
        chainAsset: ChainAsset
    ) {
        guard
            let rewardDetailsView = AnalyticsRewardDetailsViewFactory.createView(
                rewardModel: rewardModel,
                wallet: wallet,
                chainAsset: chainAsset
            )
        else { return }

        let navigationController = FearlessNavigationController(rootViewController: rewardDetailsView.controller)

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardPayoutsForNominator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory.createViewForNominator(
            chainAsset: chainAsset,
            wallet: wallet,
            stashAddress: stashAddress
        ) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }

    func showRewardPayoutsForValidator(
        from view: ControllerBackedProtocol?,
        stashAddress: AccountAddress,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let rewardPayoutsView = StakingRewardPayoutsViewFactory.createViewForValidator(
            chainAsset: chainAsset,
            wallet: wallet,
            stashAddress: stashAddress
        ) else { return }

        let navigationController = ImportantFlowViewFactory.createNavigation(
            from: rewardPayoutsView.controller
        )

        view?.controller.present(navigationController, animated: true, completion: nil)
    }
}
