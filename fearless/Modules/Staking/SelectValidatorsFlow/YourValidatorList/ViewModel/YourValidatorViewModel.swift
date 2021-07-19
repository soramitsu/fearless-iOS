import Foundation
import SoraFoundation
import FearlessUtils

enum YourValidatorListViewState {
    case loading
    case validatorList(viewModel: YourValidatorListViewModel)
    case error(LocalizableResource<String>)

    var validatorListViewModel: YourValidatorListViewModel? {
        switch self {
        case let .validatorList(viewModel):
            return viewModel
        default:
            return nil
        }
    }

    var error: LocalizableResource<String>? {
        switch self {
        case let .error(title):
            return title
        default:
            return nil
        }
    }
}

struct YourValidatorListViewModel {
    let hasValidatorWithoutRewards: Bool
    let sections: [YourValidatorListSection]
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
    let icon: DrawableIcon
    let name: String?
    let amount: String?
    let apy: String?
    let shouldHaveWarning: Bool
    let shouldHaveError: Bool
}
