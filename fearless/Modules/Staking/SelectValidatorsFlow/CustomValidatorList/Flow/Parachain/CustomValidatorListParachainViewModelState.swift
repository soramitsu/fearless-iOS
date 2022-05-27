import Foundation

class CustomValidatorListParachainViewModelState: CustomValidatorListViewModelState {
    let candidates: [ParachainStakingCandidateInfo]
    let maxTargets: Int
    let bonding: InitiatedBonding
    let selectedValidatorList: SharedList<ParachainStakingCandidateInfo>

    var filteredValidatorList: [ParachainStakingCandidateInfo] = []

    init(
        candidates: [ParachainStakingCandidateInfo],
        maxTargets: Int,
        bonding: InitiatedBonding,
        selectedValidatorList: SharedList<ParachainStakingCandidateInfo>
    ) {
        self.candidates = candidates
        self.maxTargets = maxTargets
        self.bonding = bonding
        self.selectedValidatorList = selectedValidatorList

        filteredValidatorList = candidates
    }

    var filter: CustomValidatorRelaychainListFilter = .recommendedFilter()

    var viewModel: CustomValidatorListViewModel?

    var stateListener: CustomValidatorListModelStateListener?

    func setStateListener(_ stateListener: CustomValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func updateViewModel(_ viewModel: CustomValidatorListViewModel) {
        self.viewModel = viewModel
    }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow? {
        .parachain(candidate: filteredValidatorList[validatorIndex])
    }

    func validatorSearchFlow() -> ValidatorSearchFlow? {
        .parachain(validatorList: candidates, selectedValidatorList: selectedValidatorList.items, delegate: self)
    }

    func validatorListFilterFlow() -> ValidatorListFilterFlow? {
        nil
    }

    func selectedValidatorListFlow() -> SelectedValidatorListFlow? {
        nil
    }
}

extension CustomValidatorListParachainViewModelState: CustomValidatorListUserInputHandler {}

extension CustomValidatorListParachainViewModelState: ValidatorSearchParachainDelegate {
    func validatorSearchDidUpdate(selectedValidatorList: [ParachainStakingCandidateInfo]) {
        self.selectedValidatorList.set(selectedValidatorList)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
