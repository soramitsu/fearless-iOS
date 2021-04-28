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
    let title: LocalizableResource<String>
    let validators: [YourValidatorViewModel]
}

enum YourValidatorsSectionStatus {
    case active
    case inactive
    case waiting
    case slashed
    case pending
}

extension YourValidatorsSectionStatus {
    init(modelStatus: ValidatorMyNominationStatus) {
        switch modelStatus {
        case .active:
            self = .active
        case .inactive:
            self = .inactive
        case .waiting:
            self = .waiting
        case .slashed:
            self = .slashed
        }
    }
}

struct YourValidatorViewModel {
    let address: AccountAddress
    let icon: DrawableIcon
    let name: String?
    let amount: LocalizableResource<String>?
    let shouldHaveWarning: Bool
}
