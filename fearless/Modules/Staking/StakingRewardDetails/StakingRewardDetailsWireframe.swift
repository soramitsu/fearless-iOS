import Foundation

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    func showPayoutConfirmation(from view: ControllerBackedProtocol?) {
        // TODO: Pass [PayoutInfo] here
        guard let confirmationView = StakingPayoutConfirmationViewFactory.createView(payouts: []) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
