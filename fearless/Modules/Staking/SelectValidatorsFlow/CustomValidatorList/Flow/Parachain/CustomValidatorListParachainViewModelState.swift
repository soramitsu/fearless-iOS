import Foundation

class CustomValidatorListParachainViewModelState: CustomValidatorListViewModelState {
    let candidates: [ParachainStakingCandidateInfo]
    let maxTargets: Int
    let bonding: InitiatedBonding
    let selectedValidatorList: SharedList<ParachainStakingCandidateInfo>

    var filteredValidatorList: [ParachainStakingCandidateInfo] = []
    var filter: CustomValidatorParachainListFilter = .recommendedFilter()

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

        filteredValidatorList = composeFilteredValidatorList(filter: CustomValidatorParachainListFilter.defaultFilter())
    }

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
        .parachain(filter: filter)
    }

    func selectedValidatorListFlow() -> SelectedValidatorListFlow? {
        .parachain(collators: selectedValidatorList.items, maxTargets: maxTargets, state: bonding)
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        guard let target = selectedValidatorList.items.first else {
            return nil
        }

        return .parachain(target: target, maxTargets: maxTargets, bonding: bonding)
    }

    func composeFilteredValidatorList(filter: CustomValidatorParachainListFilter) -> [ParachainStakingCandidateInfo] {
        let composer = CustomValidatorParachainListComposer(filter: filter)
        return composer.compose(from: candidates)
    }

    var filterApplied: Bool {
        let emptyFilter = CustomValidatorParachainListFilter.defaultFilter()
        return filter != emptyFilter
    }
}

extension CustomValidatorListParachainViewModelState: CustomValidatorListUserInputHandler {
    func proceed() {
        stateListener?.showConfirmation()
    }

    func changeValidatorSelection(at index: Int) {
        let validator = filteredValidatorList[index]

        selectedValidatorList.set([validator])

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func remove(validator: ParachainStakingCandidateInfo) {
        if let displayedIndex = filteredValidatorList.firstIndex(of: validator) {
            changeValidatorSelection(at: displayedIndex)
        } else if let selectedIndex = selectedValidatorList.firstIndex(of: validator) {
            selectedValidatorList.remove(at: selectedIndex)

            stateListener?.modelStateDidChanged(viewModelState: self)
        }
    }

    func remove(validatorAddress: AccountAddress) {
        guard let validator = filteredValidatorList.first(where: { $0.address == validatorAddress }) else {
            return
        }

        remove(validator: validator)
    }

    func clearFilter() {
        filter = CustomValidatorParachainListFilter.defaultFilter()
        filteredValidatorList = composeFilteredValidatorList(filter: filter)
    }

    func updateFilter(with flow: ValidatorListFilterFlow) {
        guard case let ValidatorListFilterFlow.parachain(updatedFilter) = flow else {
            return
        }

        filter = updatedFilter

        filteredValidatorList = composeFilteredValidatorList(filter: updatedFilter)
    }
}

extension CustomValidatorListParachainViewModelState: ValidatorSearchParachainDelegate {
    func validatorSearchDidUpdate(selectedValidatorList: [ParachainStakingCandidateInfo]) {
        self.selectedValidatorList.set(selectedValidatorList)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
