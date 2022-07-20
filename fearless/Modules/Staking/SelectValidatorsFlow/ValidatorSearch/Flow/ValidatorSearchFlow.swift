import Foundation

enum ValidatorSearchError: Error {
    case validatorBlocked
}

enum ValidatorSearchFlow {
    case relaychain(
        validatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchRelaychainDelegate
    )

    case parachain(
        validatorList: [ParachainStakingCandidateInfo],
        selectedValidatorList: [ParachainStakingCandidateInfo],
        delegate: ValidatorSearchParachainDelegate
    )
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
    var searchString: String { get set }

    func setStateListener(_ stateListener: ValidatorSearchModelStateListener?)
    func updateViewModel(_ viewModel: ValidatorSearchViewModel?)
    func validatorInfoFlow(index: Int) -> ValidatorInfoFlow?
    func reset()
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
    func performValidatorSearch(accountId: AccountId)
}

protocol ValidatorSearchUserInputHandler {
    func performFullAddressSearch(by address: AccountAddress, accountId: AccountId)
    func performSearch()
    func changeValidatorSelection(at index: Int)
    func applyChanges()
}

extension ValidatorSearchUserInputHandler {
    func performFullAddressSearch(by _: AccountAddress, accountId _: AccountId) {}
    func performSearch() {}
    func changeValidatorSelection(at _: Int) {}
    func applyChanges() {}
}
