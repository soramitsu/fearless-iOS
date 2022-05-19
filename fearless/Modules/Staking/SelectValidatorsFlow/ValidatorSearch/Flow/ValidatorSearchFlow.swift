import Foundation

enum ValidatorSearchError: Error {
    case validatorBlocked
}

enum ValidatorSearchFlow {
    case relaychain(validatorList: [SelectedValidatorInfo], selectedValidatorList: [SelectedValidatorInfo])
    case parachain
}

protocol ValidatorSearchModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: ValidatorSearchViewModelState)
    func viewModelChanged(_ viewModel: ValidatorSearchViewModel)

    func didStartLoading()
    func didStopLoading()
    func didReceiveError(error: Error)
    func didNotFoundLocalValidator(accountId: AccountId)
}

protocol ValidatorSearchViewModelState: ValidatorSearchUserInputHandler {
    var stateListener: ValidatorSearchModelStateListener? { get set }
    var selectedValidatorList: [SelectedValidatorInfo] { get set }

    func setStateListener(_ stateListener: ValidatorSearchModelStateListener?)
    func updateViewModel(_ viewModel: ValidatorSearchViewModel?)
    func reset()

    var searchString: String { get set }
}

struct ValidatorSearchDependencyContainer {
    let viewModelState: ValidatorSearchViewModelState
    let strategy: ValidatorSearchStrategy
    let viewModelFactory: ValidatorSearchViewModelFactoryProtocol
}

protocol ValidatorSearchViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: ValidatorSearchViewModelState,
        locale: Locale
    ) -> ValidatorSearchViewModel?
}

protocol ValidatorSearchStrategy {
    func setup()
    func performValidatorSearch(accountId: AccountId)
}

protocol ValidatorSearchUserInputHandler {
    func performFullAddressSearch(by address: AccountAddress, accountId: AccountId)
    func performSearch()
    func changeValidatorSelection(at index: Int)
}

extension ValidatorSearchUserInputHandler {
    func performFullAddressSearch(by _: AccountAddress, accountId _: AccountId) {}
    func performSearch() {}
    func changeValidatorSelection(at _: Int) {}
}
