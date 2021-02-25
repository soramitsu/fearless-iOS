import Foundation
import FearlessUtils

enum RewardDestinationTypeViewModel {
    case restake
    case payout(icon: DrawableIcon, title: String)
}

protocol RewardDestinationViewModelProtocol {
    var restakeAmount: String { get }
    var restakePercentage: String { get }
    var payoutAmount: String { get }
    var payoutPercentage: String { get }
    var type: RewardDestinationTypeViewModel { get }
}

struct RewardDestinationViewModel: RewardDestinationViewModelProtocol {
    let restakeAmount: String
    let restakePercentage: String
    let payoutAmount: String
    let payoutPercentage: String
    let type: RewardDestinationTypeViewModel
}
