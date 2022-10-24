import Foundation

enum YourValidatorListFlowError: Error {
    case validatorBlocked
}

enum YourValidatorListFlow {
    case relaychain
    case pool
}

protocol YourValidatorListModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: YourValidatorListViewModelState)
    func didReceiveError(error: Error)
    func didReceiveState(_ state: YourValidatorListViewState)

    func handleControllerAccountMissing(_ address: String)
}

protocol YourValidatorListViewModelState: YourValidatorListUserInputHandler {
    var stateListener: YourValidatorListModelStateListener? { get set }

    func setStateListener(_ stateListener: YourValidatorListModelStateListener?)
    func selectValidatorsStartFlow() -> SelectValidatorsStartFlow?
    func validatorInfoFlow(address: String) -> ValidatorInfoFlow?
    func resetState()
    func changeLocale(_ locale: Locale)
}

struct YourValidatorListDependencyContainer {
    let viewModelState: YourValidatorListViewModelState
    let strategy: YourValidatorListStrategy
    let viewModelFactory: YourValidatorListViewModelFactoryProtocol
}

protocol YourValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: YourValidatorListViewModelState,
        locale: Locale
    ) -> YourValidatorListViewModel?
}

protocol YourValidatorListStrategy {
    func setup()
    func refresh()
}

protocol YourValidatorListUserInputHandler {}
