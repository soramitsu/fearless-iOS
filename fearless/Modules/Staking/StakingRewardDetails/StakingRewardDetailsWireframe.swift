import Foundation

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?, payoutInfo: PayoutInfo) {
        guard
            let confirmationView = StakingPayoutConfirmationViewFactory.createView(payouts: [payoutInfo])
        else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
