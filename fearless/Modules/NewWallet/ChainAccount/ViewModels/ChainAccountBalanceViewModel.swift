import Foundation
import FearlessFoundation

struct ChainAccountBalanceViewModel {
    let transferrableValue: LocalizableResource<BalanceViewModelProtocol>
    let lockedValue: LocalizableResource<BalanceViewModelProtocol>
    let hasLockedTokens: Bool
}
