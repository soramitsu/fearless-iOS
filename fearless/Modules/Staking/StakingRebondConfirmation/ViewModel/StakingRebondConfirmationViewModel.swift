import Foundation
import SSFUtils
import FearlessFoundation

struct StakingRebondConfirmationViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon?
    let senderName: String?
    let amount: LocalizableResource<String>
}
