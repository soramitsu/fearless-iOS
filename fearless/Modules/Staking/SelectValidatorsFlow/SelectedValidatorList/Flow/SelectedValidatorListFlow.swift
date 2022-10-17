import UIKit

enum SelectedValidatorListFlow {
    case relaychainInitiated(validatorList: [SelectedValidatorInfo], maxTargets: Int, state: InitiatedBonding)
    case relaychainExisting(validatorList: [SelectedValidatorInfo], maxTargets: Int, state: ExistingBonding)
    case parachain(collators: [ParachainStakingCandidateInfo], maxTargets: Int, state: InitiatedBonding)
    case poolInitiated(validatorList: [SelectedValidatorInfo], poolId: UInt32, maxTargets: Int, state: InitiatedBonding)
    case poolExisting(validatorList: [SelectedValidatorInfo], poolId: UInt32, maxTargets: Int, state: ExistingBonding)
}

protocol SelectedValidatorListModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: SelectedValidatorListViewModelState)
    func validatorRemovedAtIndex(_ index: Int, viewModelState: SelectedValidatorListViewModelState)
}

protocol SelectedValidatorListViewModelState: SelectedValidatorListUserInputHandler {
    var stateListener: SelectedValidatorListModelStateListener? { get set }
    var delegate: SelectedValidatorListDelegate? { get set }

    func setStateListener(_ stateListener: SelectedValidatorListModelStateListener?)
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
