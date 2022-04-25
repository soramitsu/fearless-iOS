import Foundation

final class StakingRewardDetailsWireframe: StakingRewardDetailsWireframeProtocol {
    func showPayoutConfirmation(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        guard
            let confirmationView = StakingPayoutConfirmationViewFactory.createView(
                chain: chain,
                asset: asset,
                selectedAccount: selectedAccount,
                payouts: [payoutInfo]
            )
        else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
