import Foundation
import SSFModels

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    func showPayoutConfirmation(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: .relaychain(payouts: [payoutInfo])
        ) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
