import Foundation

class RecommendedValidatorListParachainViewModelState: RecommendedValidatorListViewModelState {
    var collators: [ParachainStakingCandidateInfo]
    var selectedCollators: [ParachainStakingCandidateInfo] = []

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
        guard let collator = selectedCollators.first else {
            return nil
        }

        return .parachain(target: collator, maxTargets: maxTargets, bonding: bonding)
    }

    func shouldSelectValidatorAt(index: Int) -> Bool {
        selectedCollators = [collators[index]]
        stateListener?.modelStateDidChanged(viewModelState: self)
        return true
    }
}
