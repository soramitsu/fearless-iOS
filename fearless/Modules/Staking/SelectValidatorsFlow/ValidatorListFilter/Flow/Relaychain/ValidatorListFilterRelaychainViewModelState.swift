import Foundation

final class ValidatorListFilterRelaychainViewModelState: ValidatorListFilterViewModelState {
    var stateListener: ValidatorListFilterModelStateListener?
    let initialFilter: CustomValidatorRelaychainListFilter
    private(set) var currentFilter: CustomValidatorRelaychainListFilter

    init(filter: CustomValidatorRelaychainListFilter) {
        initialFilter = filter
        currentFilter = filter
    }

    func setStateListener(_ stateListener: ValidatorListFilterModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorListFilterFlow() -> ValidatorListFilterFlow? {
        .relaychain(filter: currentFilter)
    }
}

extension ValidatorListFilterRelaychainViewModelState: ValidatorListFilterUserInputHandler {
    func toggleFilterItem(at index: Int) {
        guard let filter = ValidatorListRelaychainFilterRow(rawValue: index) else {
            return
        }

        switch filter {
        case .withoutIdentity:
            currentFilter.allowsNoIdentity.toggle()
        case .slashed:
            currentFilter.allowsSlashed.toggle()
        case .oversubscribed:
            currentFilter.allowsOversubscribed.toggle()
        case .clusterLimit:
            let allowsUnlimitedClusters = currentFilter.allowsClusters == .unlimited
            currentFilter.allowsClusters = allowsUnlimitedClusters ?
                .limited(amount: StakingConstants.targetsClusterLimit) :
                .unlimited
        }

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func selectFilterItem(at index: Int) {
        guard let sortRow = ValidatorListRelaychainSortRow(rawValue: index) else {
            return
        }

        currentFilter.sortedBy = sortRow.sortCriterion
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func resetFilter() {
        currentFilter = CustomValidatorRelaychainListFilter.recommendedFilter()
        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
