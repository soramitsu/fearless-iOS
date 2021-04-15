import Foundation

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {
    func showRewardDetails(from view: ControllerBackedProtocol?, payoutItem: StakingPayoutItem) {
        guard
            let rewardDetails = StakingRewardDetailsViewFactory.createView(payoutItem: payoutItem)
        else { return }
        view?.controller
            .navigationController?
            .pushViewController(rewardDetails.controller, animated: true)
    }
}
