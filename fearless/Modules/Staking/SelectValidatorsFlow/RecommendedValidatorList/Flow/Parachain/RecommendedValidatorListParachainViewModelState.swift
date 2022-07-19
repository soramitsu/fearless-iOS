import Foundation

// swiftlint:disable type_name
final class RecommendedValidatorListParachainViewModelState: RecommendedValidatorListViewModelState {
    var stateListener: RecommendedValidatorListModelStateListener?
    private(set) var collators: [ParachainStakingCandidateInfo]
    private(set) var selectedCollators: [ParachainStakingCandidateInfo] = []
    let bonding: InitiatedBonding
    let maxTargets: Int

    init(collators: [ParachainStakingCandidateInfo], bonding: InitiatedBonding, maxTargets: Int) {
        self.collators = collators.sorted(by: { collator1, collator2 in
            collator1.subqueryData?.apr ?? 0.0 > collator2.subqueryData?.apr ?? 0.0
        })
        self.bonding = bonding
        self.maxTargets = maxTargets
    }

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
