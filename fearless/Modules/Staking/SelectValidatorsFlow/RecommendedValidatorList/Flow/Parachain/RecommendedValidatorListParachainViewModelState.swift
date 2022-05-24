import Foundation

class RecommendedValidatorListParachainViewModelState: RecommendedValidatorListViewModelState {
    var stateListener: RecommendedValidatorListModelStateListener?

    func setStateListener(_ stateListener: RecommendedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorInfoFlow(validatorIndex _: Int) -> ValidatorInfoFlow? {
        .parachain
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        .parachain
    }
}
