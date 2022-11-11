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
    private var iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

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

            rewardDestViewModel = .payout(
                icon: payoutIcon,
                title: try account.toDisplayAddress().username,
                address: try account.toDisplayAddress().address
            )
        }

        return StakingRewardDestConfirmViewModel(
            senderIcon: icon,
            senderName: try controller?.toDisplayAddress().username ?? stashItem.controller,
            rewardDestination: rewardDestViewModel
        )
    }
}
