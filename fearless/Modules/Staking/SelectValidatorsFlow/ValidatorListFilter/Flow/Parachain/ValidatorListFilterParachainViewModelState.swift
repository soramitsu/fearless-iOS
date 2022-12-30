import Foundation

final class ValidatorListFilterParachainViewModelState: ValidatorListFilterViewModelState {
    var stateListener: ValidatorListFilterModelStateListener?
    let initialFilter: CustomValidatorParachainListFilter
    private(set) var currentFilter: CustomValidatorParachainListFilter

    init(filter: CustomValidatorParachainListFilter) {
        initialFilter = filter
        currentFilter = filter
    }

    func setStateListener(_ stateListener: ValidatorListFilterModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorListFilterFlow() -> ValidatorListFilterFlow? {
        .parachain(filter: currentFilter)
    }
}

extension ValidatorListFilterParachainViewModelState: ValidatorListFilterUserInputHandler {
    func toggleFilterItem(at index: Int) {
        guard let filter = ValidatorListParachainFilterRow(rawValue: index) else {
            return
        }

        switch filter {
        case .withoutIdentity:
            currentFilter.allowsNoIdentity = !currentFilter.allowsNoIdentity
        case .oversubscribed:
            currentFilter.allowsOversubscribed = !currentFilter.allowsOversubscribed
        }

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func selectFilterItem(at index: Int) {
        guard let sortRow = ValidatorListParachainSortRow(rawValue: index) else {
            return
        }

        currentFilter.sortedBy = sortRow.sortCriterion
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func resetFilter() {
        currentFilter = CustomValidatorParachainListFilter.recommendedFilter()
        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
