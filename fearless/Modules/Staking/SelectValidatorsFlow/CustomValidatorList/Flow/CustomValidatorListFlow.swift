import Foundation

enum CustomValidatorListFlowError {
    case validatorBlocked
}

enum CustomValidatorListFlow {
    case parachain(
        candidates: [ParachainStakingCandidateInfo],
        maxTargets: Int,
        bonding: InitiatedBonding,
        selectedValidatorList: SharedList<ParachainStakingCandidateInfo>
    )
    case relaychainInitiated(
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        bonding: InitiatedBonding
    )
    case relaychainExisting(
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int,
        bonding: ExistingBonding
    )
    case poolExisting(
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        poolId: UInt32,
        maxTargets: Int,
        bonding: ExistingBonding
    )
    case poolInitiated(
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        poolId: UInt32,
        maxTargets: Int,
        bonding: InitiatedBonding
    )
}

protocol CustomValidatorListModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: CustomValidatorListViewModelState)
    func didReceiveError(error: CustomValidatorListFlowError)
    func showSelectedList()
    func showConfirmation()
}

protocol CustomValidatorListViewModelState: CustomValidatorListUserInputHandler {
    var stateListener: CustomValidatorListModelStateListener? { get set }
    var filterApplied: Bool { get }

    func setStateListener(_ stateListener: CustomValidatorListModelStateListener?)
    func updateViewModel(_ viewModel: CustomValidatorListViewModel)

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow?
    func validatorSearchFlow() -> ValidatorSearchFlow?
    func validatorListFilterFlow() -> ValidatorListFilterFlow?
    func selectedValidatorListFlow() -> SelectedValidatorListFlow?
    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow?
}

struct CustomValidatorListDependencyContainer {
    let viewModelState: CustomValidatorListViewModelState
    let strategy: CustomValidatorListStrategy
    let viewModelFactory: CustomValidatorListViewModelFactoryProtocol
}

protocol CustomValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: CustomValidatorListViewModelState,
        priceData: PriceData?,
        locale: Locale
    ) -> CustomValidatorListViewModel?
}

protocol CustomValidatorListStrategy {
    func setup()
}

protocol CustomValidatorListUserInputHandler {
    func remove(validator: SelectedValidatorInfo)
    func remove(validatorAddress: AccountAddress)

    func fillWithRecommended()
    func performDeselect()
    func changeIdentityFilterValue()
    func changeMinBondFilterValue()
    func changeValidatorSelection(at index: Int)
    func updateFilter(with flow: ValidatorListFilterFlow)
    func clearFilter()
    func proceed()
}

extension CustomValidatorListUserInputHandler {
    func remove(validator _: SelectedValidatorInfo) {}
    func fillWithRecommended() {}
    func changeIdentityFilterValue() {}
    func changeMinBondFilterValue() {}
    func performDeselect() {}
    func changeValidatorSelection(at _: Int) {}
    func updateFilter(with _: ValidatorListFilterFlow) {}
    func clearFilter() {}
    func proceed() {}
}
