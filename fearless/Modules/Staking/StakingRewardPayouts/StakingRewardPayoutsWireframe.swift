import Foundation

final class StakingRewardPayoutsWireframe: StakingRewardPayoutsWireframeProtocol {
    func showRewardDetails(
        from view: ControllerBackedProtocol?,
        payoutInfo: PayoutInfo,
        activeEra: EraIndex,
        historyDepth: UInt32,
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel
    ) {
        let input = StakingRewardDetailsInput(
            payoutInfo: payoutInfo,
            chain: chain,
            activeEra: activeEra,
            historyDepth: historyDepth
        )
        guard
            let rewardDetails = StakingRewardDetailsViewFactory.createView(
                selectedAccount: selectedAccount,
                chain: chain,
                asset: asset,
                input: input
            )
        else { return }
        view?.controller
            .navigationController?
            .pushViewController(rewardDetails.controller, animated: true)
    }

    func showPayoutConfirmation(
        for payouts: [PayoutInfo],
        chain: ChainModel,
        asset: AssetModel,
        selectedAccount: MetaAccountModel,
        from view: ControllerBackedProtocol?
    ) {
        guard let confirmationView = StakingPayoutConfirmationViewFactory.createView(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: selectedAccount,
            payouts: payouts,
            flow: .relaychain
        ) else { return }

        view?.controller
            .navigationController?
            .pushViewController(confirmationView.controller, animated: true)
    }
}
