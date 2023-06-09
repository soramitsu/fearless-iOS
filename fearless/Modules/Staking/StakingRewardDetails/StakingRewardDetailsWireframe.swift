import Foundation
import SSFModels

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    func showPayoutConfirmation(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory.createView(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: selectedAccount,
            flow: .relaychain(payouts: [payoutInfo])
        ) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
