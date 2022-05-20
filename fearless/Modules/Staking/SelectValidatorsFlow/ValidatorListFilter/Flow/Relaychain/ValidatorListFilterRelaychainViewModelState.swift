import Foundation

final class ValidatorListFilterRelaychainViewModelState: ValidatorListFilterViewModelState {
    var stateListener: ValidatorListFilterModelStateListener?

    func setStateListener(_ stateListener: ValidatorListFilterModelStateListener?) {
        self.stateListener = stateListener
    }

    let initialFilter: CustomValidatorListFilter
    private(set) var currentFilter: CustomValidatorListFilter

    init(filter: CustomValidatorListFilter) {
        initialFilter = filter
        currentFilter = filter
    }

    func validatorListFilterFlow() -> ValidatorListFilterFlow? {
        .relaychain(filter: currentFilter)
    }
}

extension ValidatorListFilterRelaychainViewModelState: ValidatorListFilterUserInputHandler {
    func toggleFilterItem(at index: Int) {
        guard let filter = ValidatorListFilterRow(rawValue: index) else {
            return
        }

        switch filter {
        case .withoutIdentity:
            currentFilter.allowsNoIdentity = !currentFilter.allowsNoIdentity
        case .slashed:
            currentFilter.allowsSlashed = !currentFilter.allowsSlashed
        case .oversubscribed:
            currentFilter.allowsOversubscribed = !currentFilter.allowsOversubscribed
        case .clusterLimit:
            let allowsUnlimitedClusters = currentFilter.allowsClusters == .unlimited
            currentFilter.allowsClusters = allowsUnlimitedClusters ?
                .limited(amount: StakingConstants.targetsClusterLimit) :
                .unlimited
        }

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func selectFilterItem(at index: Int) {
        guard let sortRow = ValidatorListSortRow(rawValue: index) else {
            return
        }

        currentFilter.sortedBy = sortRow.sortCriterion
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func resetFilter() {
        currentFilter = CustomValidatorListFilter.recommendedFilter()
        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
