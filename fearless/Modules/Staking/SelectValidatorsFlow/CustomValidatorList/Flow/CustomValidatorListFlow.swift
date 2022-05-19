import Foundation

enum CustomValidatorListFlowError {
    case validatorBlocked
}

enum CustomValidatorListFlow {
    case parachain
    case relaychain(
        validatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int
    )
}

protocol CustomValidatorListModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: CustomValidatorListViewModelState)
    func viewModelChanged(_ viewModel: CustomValidatorListViewModel, at indexes: [Int]?)
    func didReceiveError(error: CustomValidatorListFlowError)
}

protocol CustomValidatorListViewModelState: CustomValidatorListUserInputHandler {
    var stateListener: CustomValidatorListModelStateListener? { get set }
    var filter: CustomValidatorListFilter { get set }

    func setStateListener(_ stateListener: CustomValidatorListModelStateListener?)
    func updateViewModel(_ viewModel: CustomValidatorListViewModel)

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow?
    func validatorSearchFlow() -> ValidatorSearchFlow?
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
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo])
    func fillWithRecommended()
    func performDeselect()
    func changeValidatorSelection(at index: Int)
    func updateFilter(_ filter: CustomValidatorListFilter)
}

extension CustomValidatorListUserInputHandler {
    func remove(validator _: SelectedValidatorInfo) {}
    func validatorSearchDidUpdate(selectedValidatorList _: [SelectedValidatorInfo]) {}
    func fillWithRecommended() {}
    func performDeselect() {}
    func changeValidatorSelection(at _: Int) {}
    func updateFilter(_: CustomValidatorListFilter) {}
}
