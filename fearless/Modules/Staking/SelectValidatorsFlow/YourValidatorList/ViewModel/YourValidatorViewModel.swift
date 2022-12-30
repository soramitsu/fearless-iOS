import Foundation
import SoraFoundation
import FearlessUtils

enum YourValidatorListViewState {
    case loading
    case validatorList(viewModel: YourValidatorListViewModel)
    case error(String)
}

struct YourValidatorListViewModel {
    let allValidatorWithoutRewards: Bool
    let sections: [YourValidatorListSection]
    let userCanSelectValidators: Bool
}

struct YourValidatorListSection {
    let status: YourValidatorListSectionStatus
    let validators: [YourValidatorViewModel]
}

enum YourValidatorListSectionStatus {
    case stakeAllocated
    case stakeNotAllocated
    case unelected
    case pending
}

struct YourValidatorViewModel {
    let address: AccountAddress
    let name: String?
    let amount: String?
    let apy: NSAttributedString?
    let staked: String?
    let shouldHaveWarning: Bool
    let shouldHaveError: Bool
}
