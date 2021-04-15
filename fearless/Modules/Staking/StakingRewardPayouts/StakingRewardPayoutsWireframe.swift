import Foundation

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutItem: PayoutInfo,
        chain: Chain
    ) {
        guard
            let rewardDetails = StakingRewardDetailsViewFactory.createView(payoutItem: payoutItem, chain: chain)
        else { return }
        view?.controller
            .navigationController?
            .pushViewController(rewardDetails.controller, animated: true)
    }
}
