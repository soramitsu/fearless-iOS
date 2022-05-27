import Foundation

enum RecommendedValidatorListFlow {
    case relaychainInitiated(validators: [SelectedValidatorInfo], maxTargets: Int, bonding: InitiatedBonding)
    case relaychainExisting(validators: [SelectedValidatorInfo], maxTargets: Int, bonding: ExistingBonding)
    case parachain(collators: [ParachainStakingCandidateInfo], maxTargets: Int, bonding: InitiatedBonding)
}

protocol RecommendedValidatorListModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: RecommendedValidatorListViewModelState)
    func viewModelChanged(_ viewModel: RecommendedValidatorListViewModel, at indexes: [Int]?)
    func didReceiveError(error: Error)
}

protocol RecommendedValidatorListViewModelState: RecommendedValidatorListUserInputHandler {
    var stateListener: RecommendedValidatorListModelStateListener? { get set }

    func setStateListener(_ stateListener: RecommendedValidatorListModelStateListener?)

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow?
    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow?
}

struct RecommendedValidatorListDependencyContainer {
    let viewModelState: RecommendedValidatorListViewModelState
    let strategy: RecommendedValidatorListStrategy
    let viewModelFactory: RecommendedValidatorListViewModelFactoryProtocol
}

protocol RecommendedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: RecommendedValidatorListViewModelState
    ) -> RecommendedValidatorListViewModel?
}

protocol RecommendedValidatorListStrategy {
    func setup()
}

protocol RecommendedValidatorListUserInputHandler {}

extension RecommendedValidatorListUserInputHandler {}
