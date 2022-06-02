import Foundation
import FearlessUtils

struct SelectedValidatorViewModel {
    let name: String?
    let address: String
}

struct SelectValidatorsConfirmViewModel {
    let senderIcon: DrawableIcon?
    let senderName: String
    let amount: String
    let rewardDestination: RewardDestinationTypeViewModel?
    let validatorsCount: Int?
    let maxValidatorCount: Int?
    let selectedCollatorViewModel: SelectedValidatorViewModel?
}
