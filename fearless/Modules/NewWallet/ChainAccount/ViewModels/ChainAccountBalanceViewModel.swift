import Foundation
import SoraFoundation

struct ChainAccountBalanceViewModel {
    let transferrableValue: LocalizableResource<BalanceViewModelProtocol>
    let lockedValue: LocalizableResource<BalanceViewModelProtocol>
    let hasLockedTokens: Bool
    /// Replaces the "Locked" title when the second row means something else: for Bitcoin it is
    /// value waiting for its first confirmation, which Send cannot spend yet.
    var lockedTitle: LocalizableResource<String>?
}
