import Foundation

enum RecommendedValidatorListFlow {
    case relaychainInitiated(validators: [SelectedValidatorInfo], maxTargets: Int, bonding: InitiatedBonding)
    case relaychainExisting(validators: [SelectedValidatorInfo], maxTargets: Int, bonding: ExistingBonding)
    case parachain(collators: [ParachainStakingCandidateInfo], maxTargets: Int, bonding: InitiatedBonding)
    case poolInitiated(poolId: UInt32, validators: [SelectedValidatorInfo], maxTargets: Int, bonding: InitiatedBonding)
    case poolExisting(poolId: UInt32, validators: [SelectedValidatorInfo], maxTargets: Int, bonding: ExistingBonding)
}

protocol RecommendedValidatorListModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: RecommendedValidatorListViewModelState)
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
        viewModelState: RecommendedValidatorListViewModelState,
        locale: Locale
    ) -> RecommendedValidatorListViewModel?
}

protocol RecommendedValidatorListStrategy {
    func setup()
}

protocol RecommendedValidatorListUserInputHandler {
    func shouldSelectValidatorAt(index: Int) -> Bool
}

extension RecommendedValidatorListUserInputHandler {
    func shouldSelectValidatorAt(index _: Int) -> Bool { false }
}
