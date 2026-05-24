import Foundation
import FearlessFoundation

struct BalanceLocksDetailStakingViewModel {
    let stakedViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let unstakingViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let redeemableViewModel: LocalizableResource<BalanceViewModelProtocol>?
}
