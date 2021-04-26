import Foundation
import SoraFoundation

enum YourValidatorsViewState {
    case loading(Bool)
    case validatorList([YourValidatorsSection])
    case emptyList
    case error(LocalizableResource<String>)
}

enum YourValidatorsSection {
    case active(validators: [YourValidatorViewModel])
    case inactive(validators: [YourValidatorViewModel])
    case waiting(validators: [YourValidatorViewModel])
    case slashed(validators: [YourValidatorViewModel])
    case pending(validators: [YourValidatorViewModel])
}

struct YourValidatorViewModel {
    let address: String
    let name: String
    let amount: String?
    let shouldHaveWarning: Bool
}
