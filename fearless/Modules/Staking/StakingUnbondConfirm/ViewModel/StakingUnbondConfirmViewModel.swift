import Foundation
import FearlessUtils
import SoraFoundation

struct StakingUnbondConfirmViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon
    let senderName: String?
    let amount: LocalizableResource<String>
    let hints: LocalizableResource<[TitleIconViewModel]>
}
