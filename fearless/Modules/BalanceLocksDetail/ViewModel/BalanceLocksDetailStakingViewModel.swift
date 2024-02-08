import Foundation
import SoraFoundation

struct BalanceLocksDetailStakingViewModel {
    let stakedViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let unstakingViewModel: LocalizableResource<BalanceViewModelProtocol>?
    let redeemableViewModel: LocalizableResource<BalanceViewModelProtocol>?
}
