import Foundation
import SSFModels

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        historyDepth: UInt32,
        chainAsset: ChainAsset,
        wallet: MetaAccountModel
    ) {
        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            chain: chainAsset.chain,
            activeEra: activeEra,
            historyDepth: historyDepth
        )
        guard
            let rewardDetails = StakingRewardDetailsViewFactory.createView(
                wallet: wallet,
                chainAsset: chainAsset,
                input: input
            )
        else { return }
        view?.controller
            .navigationController?
            .pushViewController(rewardDetails.controller, animated: true)
    }

    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        chainAsset: ChainAsset,
        wallet: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory.createView(
            chainAsset: chainAsset,
            wallet: wallet,
            flow: .relaychain(payouts: payouts)
        ) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
