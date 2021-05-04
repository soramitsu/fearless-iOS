import Foundation
import FearlessUtils
import SoraFoundation

struct StakingRedeemViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon
    let senderName: String?
    let amount: LocalizableResource<String>
    let shouldResetRewardDestination: Bool
}
