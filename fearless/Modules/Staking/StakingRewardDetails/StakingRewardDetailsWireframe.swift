import Foundation

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory.createView(payouts: []) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
