import Foundation
import SSFUtils
import SoraFoundation

struct StakingRedeemViewModel {
    let senderAddress: AccountAddress
    let senderIcon: DrawableIcon?
    let senderName: String?
    let amount: LocalizableResource<String>
    let title: LocalizableResource<String>
    let collatorName: String?
    let collatorIcon: DrawableIcon?
}
