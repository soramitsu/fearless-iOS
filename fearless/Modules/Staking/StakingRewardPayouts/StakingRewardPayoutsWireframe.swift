import Foundation

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        historyDepth: UInt32,
        chain: Chain
    ) {
        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            chain: chain,
            activeEra: activeEra,
            historyDepth: historyDepth
        )
        guard
            let rewardDetails = StakingRewardDetailsViewFactory.createView(input: input)
        else { return }
        view?.controller
            .navigationController?
            .pushViewController(rewardDetails.controller, animated: true)
    }

    func showPayoutConfirmation(for payouts: [PayoutInfo], from view: ControllerBackedProtocol?) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory
            .createView(payouts: payouts) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
