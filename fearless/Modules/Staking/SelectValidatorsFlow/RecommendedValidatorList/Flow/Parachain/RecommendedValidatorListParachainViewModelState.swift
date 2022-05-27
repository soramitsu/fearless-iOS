import Foundation

class RecommendedValidatorListParachainViewModelState: RecommendedValidatorListViewModelState {
    var collators: [ParachainStakingCandidateInfo]
    let bonding: InitiatedBonding
    let maxTargets: Int

    init(collators: [ParachainStakingCandidateInfo], bonding: InitiatedBonding, maxTargets: Int) {
        self.collators = collators
        self.bonding = bonding
        self.maxTargets = maxTargets
    }

    var stateListener: RecommendedValidatorListModelStateListener?

    func setStateListener(_ stateListener: RecommendedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow? {
        .parachain(candidate: collators[validatorIndex])
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        .parachain
    }
}
