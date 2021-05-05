import Foundation
import FearlessUtils
import SoraFoundation

struct StakingBondMoreConfirmViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon
    let senderName: String?
    let amount: LocalizableResource<String>
}
