import Foundation

class CustomValidatorListParachainViewModelState: CustomValidatorListViewModelState {
    let candidates: [ParachainStakingCandidateInfo]
    let maxTargets: Int
    let bonding: InitiatedBonding
    let selectedValidatorList: SharedList<ParachainStakingCandidateInfo>
    let chainAsset: ChainAsset

    var filteredValidatorList: [ParachainStakingCandidateInfo] = []
    var filter: CustomValidatorParachainListFilter = .recommendedFilter()

    init(
        candidates: [ParachainStakingCandidateInfo],
        maxTargets: Int,
        bonding: InitiatedBonding,
        selectedValidatorList: SharedList<ParachainStakingCandidateInfo>,
        chainAsset: ChainAsset
    ) {
        self.candidates = candidates
        self.maxTargets = maxTargets
        self.bonding = bonding
        self.selectedValidatorList = selectedValidatorList
        self.chainAsset = chainAsset

        filteredValidatorList = composeFilteredValidatorList(filter: CustomValidatorParachainListFilter.recommendedFilter())
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
        let extractedExpr = CustomValidatorParachainListComposer(
            filter: filter,
            chainAsset: chainAsset
        )
        let composer = extractedExpr
        return composer.compose(
            from: candidates,
            stakeAmount: bonding.amount
        )
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

    func changeIdentityFilterValue() {
        filter.allowsNoIdentity = !filter.allowsNoIdentity
        filteredValidatorList = composeFilteredValidatorList(filter: filter)
        stateListener?.modelStateDidChanged(viewModelState: self)
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
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func updateFilter(with flow: ValidatorListFilterFlow) {
        guard case let ValidatorListFilterFlow.parachain(updatedFilter) = flow else {
            return
        }

        filter = updatedFilter

        filteredValidatorList = composeFilteredValidatorList(filter: updatedFilter)
        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}

extension CustomValidatorListParachainViewModelState: ValidatorSearchParachainDelegate {
    func validatorSearchDidUpdate(selectedValidatorList: [ParachainStakingCandidateInfo]) {
        self.selectedValidatorList.set(selectedValidatorList)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
