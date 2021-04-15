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

    func showPayoutConfirmation(from view: ControllerBackedProtocol?) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory.createView() else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
