import Foundation

struct YourValidatorsModel {
    let currentValidators: [SelectedValidatorInfo]
    let pendingValidators: [SelectedValidatorInfo]

    var allValidators: [SelectedValidatorInfo] {
        currentValidators + pendingValidators
    }

    static func empty() -> YourValidatorsModel {
        YourValidatorsModel(currentValidators: [], pendingValidators: [])
    }
}
