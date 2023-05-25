import Foundation
import SoraFoundation

struct ChainAccountBalanceViewModel {
    let transferrableValue: LocalizableResource<BalanceViewModelProtocol>
    let lockedValue: LocalizableResource<BalanceViewModelProtocol>
}
