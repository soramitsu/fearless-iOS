import Foundation
import FearlessUtils

protocol StakingRewardDestConfirmVMFactoryProtocol {
    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<AccountItem>,
        controller: AccountItem?
    ) throws -> StakingRewardDestConfirmViewModel
}

final class StakingRewardDestConfirmVMFactory: StakingRewardDestConfirmVMFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()
    private lazy var amountFactory = AmountFormatterFactory()

    func createViewModel(
        from stashItem: StashItem,
        rewardDestination: RewardDestination<AccountItem>,
        controller: AccountItem?
    ) throws -> StakingRewardDestConfirmViewModel {
        let icon = try iconGenerator.generateFromAddress(stashItem.controller)

        let rewardDestViewModel: RewardDestinationTypeViewModel

        switch rewardDestination {
        case .restake:
            rewardDestViewModel = .restake
        case let .payout(account):
            let payoutIcon = try iconGenerator.generateFromAddress(account.address)

            rewardDestViewModel = .payout(icon: payoutIcon, title: account.username)
        }

        return StakingRewardDestConfirmViewModel(
            senderIcon: icon,
            senderName: controller?.username ?? stashItem.controller,
            rewardDestination: rewardDestViewModel
        )
    }
}
