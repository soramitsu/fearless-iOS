import Foundation
import FearlessUtils

protocol StakingConfirmViewModelProtocol {
    var senderIcon: DrawableIcon { get }
    var senderName: String { get }
    var amount: String { get }
    var rewardDestination: RewardDestinationTypeViewModel { get }
    var validatorsCount: Int { get }
}

struct StakingConfirmViewModel: StakingConfirmViewModelProtocol {
    let senderIcon: DrawableIcon
    let senderName: String
    let amount: String
    let rewardDestination: RewardDestinationTypeViewModel
    let validatorsCount: Int
}
