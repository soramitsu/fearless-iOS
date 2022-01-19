import Foundation
import FearlessUtils

protocol StakingRewardDestConfirmVMFactoryProtocol {
    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        controller: ChainAccountResponse?
    ) throws -> StakingRewardDestConfirmViewModel
}

final class StakingRewardDestConfirmVMFactory: StakingRewardDestConfirmVMFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<ChainAccountResponse>,
        controller: ChainAccountResponse?
    ) throws -> StakingRewardDestConfirmViewModel {
        let icon = try iconGenerator.generateFromAddress(stashItem.controller)

        let rewardDestViewModel: RewardDestinationTypeViewModel

        switch rewardDestination {
        case .restake:
            rewardDestViewModel = .restake
        case let .payout(account):
            let payoutIcon = try iconGenerator.generateFromAddress(account.toDisplayAddress().address)

            rewardDestViewModel = .payout(icon: payoutIcon, title: try account.toDisplayAddress().username)
        }

        return StakingRewardDestConfirmViewModel(
            senderIcon: icon,
            senderName: try controller?.toDisplayAddress().username ?? stashItem.controller,
            rewardDestination: rewardDestViewModel
        )
    }
}
