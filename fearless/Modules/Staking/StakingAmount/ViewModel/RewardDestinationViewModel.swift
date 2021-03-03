import Foundation
import FearlessUtils

enum RewardDestinationTypeViewModel {
    case restake
    case payout(icon: DrawableIcon, title: String)
}

protocol DestinationReturnViewModelProtocol {
    var restakeAmount: String { get }
    var restakePercentage: String { get }
    var payoutAmount: String { get }
    var payoutPercentage: String { get }
}

protocol RewardDestinationViewModelProtocol {
    var rewardViewModel: DestinationReturnViewModelProtocol? { get }
    var type: RewardDestinationTypeViewModel { get }
}

struct RewardDestinationViewModel: RewardDestinationViewModelProtocol {
    let rewardViewModel: DestinationReturnViewModelProtocol?
    let type: RewardDestinationTypeViewModel
}

struct DestinationReturnViewModel: DestinationReturnViewModelProtocol {
    let restakeAmount: String
    let restakePercentage: String
    let payoutAmount: String
    let payoutPercentage: String
}
