import Foundation
import FearlessUtils

protocol SelectValidatorsConfirmViewModelProtocol {
    var senderIcon: DrawableIcon { get }
    var senderName: String { get }
    var amount: String { get }
    var rewardDestination: RewardDestinationTypeViewModel { get }
    var validatorsCount: Int { get }
}

struct SelectValidatorsConfirmViewModel: SelectValidatorsConfirmViewModelProtocol {
    let senderIcon: DrawableIcon
    let senderName: String
    let amount: String
    let rewardDestination: RewardDestinationTypeViewModel
    let validatorsCount: Int
}
