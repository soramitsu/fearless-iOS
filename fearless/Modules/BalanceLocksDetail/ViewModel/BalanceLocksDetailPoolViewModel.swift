import Foundation
import FearlessFoundation

struct BalanceLocksDetailPoolViewModel {
    let stakedViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let unstakingViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let redeemableViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let claimableViewModel: LocalizableResource<BalanceViewModelProtocol>?
}
