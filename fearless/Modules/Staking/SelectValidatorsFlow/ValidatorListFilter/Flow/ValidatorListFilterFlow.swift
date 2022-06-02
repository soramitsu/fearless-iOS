import Foundation

enum ValidatorListFilterFlow {
    case relaychain(filter: CustomValidatorRelaychainListFilter)
    case parachain(filter: CustomValidatorParachainListFilter)
}

protocol ValidatorListFilterModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: ValidatorListFilterViewModelState)
}

protocol ValidatorListFilterViewModelState: ValidatorListFilterUserInputHandler {
    var stateListener: ValidatorListFilterModelStateListener? { get set }
    func setStateListener(_ stateListener: ValidatorListFilterModelStateListener?)

    func validatorListFilterFlow() -> ValidatorListFilterFlow?
}

protocol ValidatorListFilterViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: ValidatorListFilterViewModelState,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModel?
}

struct ValidatorListFilterDependencyContainer {
    let viewModelState: ValidatorListFilterViewModelState
    let viewModelFactory: ValidatorListFilterViewModelFactoryProtocol
}

protocol ValidatorListFilterUserInputHandler {
    func toggleFilterItem(at index: Int)
    func selectFilterItem(at index: Int)
    func resetFilter()
}

extension ValidatorListFilterUserInputHandler {
    func toggleFilterItem(at _: Int) {}
    func selectFilterItem(at _: Int) {}
    func resetFilter() {}
}
