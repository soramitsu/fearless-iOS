import Foundation

class RecommendedValidatorListRelaychainViewModelState: RecommendedValidatorListViewModelState {
    var stateListener: RecommendedValidatorListModelStateListener?

    func setStateListener(_ stateListener: RecommendedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    var validators: [SelectedValidatorInfo]
    var maxTargets: Int

    init(validators: [SelectedValidatorInfo], maxTargets: Int) {
        self.validators = validators
        self.maxTargets = maxTargets
    }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow? {
        .relaychain(validatorInfo: validators[validatorIndex], address: nil)
    }
}
