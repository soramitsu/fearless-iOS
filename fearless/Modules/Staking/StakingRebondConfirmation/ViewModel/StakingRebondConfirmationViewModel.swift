import Foundation
import FearlessUtils
import SoraFoundation

struct StakingRebondConfirmationViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon
    let senderName: String?
    let amount: LocalizableResource<String>
}
