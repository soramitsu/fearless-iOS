import Foundation
import SoraFoundation
import FearlessUtils

enum YourValidatorsViewState {
    case loading
    case validatorList([YourValidatorsSection])
    case error(LocalizableResource<String>)

    var validatorSections: [YourValidatorsSection]? {
        switch self {
        case let .validatorList(sections):
            return sections
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

struct YourValidatorsSection {
    let status: YourValidatorsSectionStatus
    let title: LocalizableResource<String>?
    let description: LocalizableResource<String>?
    let validators: [YourValidatorViewModel]
}

enum YourValidatorsSectionStatus {
    case stakeAllocated
    case stakeNotAllocated
    case inactive
    case pending
}

struct YourValidatorViewModel {
    let address: AccountAddress
    let icon: DrawableIcon
    let name: String?
    let amount: LocalizableResource<String>?
    let shouldHaveWarning: Bool
    let shouldHaveError: Bool
}
