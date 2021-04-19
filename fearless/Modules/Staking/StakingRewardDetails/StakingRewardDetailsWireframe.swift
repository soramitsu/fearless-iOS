import Foundation

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    func showPayoutConfirmation(for payoutInfo: PayoutInfo, from view: ControllerBackedProtocol?) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory
            .createView(payouts: [payoutInfo]) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
