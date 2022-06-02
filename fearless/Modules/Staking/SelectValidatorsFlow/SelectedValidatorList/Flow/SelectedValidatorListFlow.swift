import UIKit

enum SelectedValidatorListFlowError: Error {}

enum SelectedValidatorListFlow {
    case relaychainInitiated(validatorList: [SelectedValidatorInfo], maxTargets: Int, state: InitiatedBonding)
    case relaychainExisting(validatorList: [SelectedValidatorInfo], maxTargets: Int, state: ExistingBonding)
    case parachain(collators: [ParachainStakingCandidateInfo], maxTargets: Int, state: InitiatedBonding)
}

protocol SelectedValidatorListModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: SelectedValidatorListViewModelState)
    func validatorRemovedAtIndex(_ index: Int, viewModelState: SelectedValidatorListViewModelState)

    func didReceiveError(error: SelectedValidatorListFlowError)
}

protocol SelectedValidatorListViewModelState: SelectedValidatorListUserInputHandler {
    var stateListener: SelectedValidatorListModelStateListener? { get set }
    func setStateListener(_ stateListener: SelectedValidatorListModelStateListener?)
    var delegate: SelectedValidatorListDelegate? { get set }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow?
    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow?
}

struct SelectedValidatorListDependencyContainer {
    let viewModelState: SelectedValidatorListViewModelState
    let viewModelFactory: SelectedValidatorListViewModelFactoryProtocol
}

protocol SelectedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: SelectedValidatorListViewModelState,
        locale: Locale
    ) -> SelectedValidatorListViewModel?
}

protocol SelectedValidatorListUserInputHandler {
    func removeItem(at index: Int)
}

extension SelectedValidatorListUserInputHandler {
    func removeItem(at _: Int) {}
}
