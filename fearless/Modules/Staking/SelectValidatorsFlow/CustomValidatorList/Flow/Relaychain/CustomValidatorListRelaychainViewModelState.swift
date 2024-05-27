import Foundation

// swiftlint:disable: type_name
final class CustomValidatorListRelaychainViewModelState: CustomValidatorListViewModelState {
    var stateListener: CustomValidatorListModelStateListener?

    func setStateListener(_ stateListener: CustomValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    let fullValidatorList: [SelectedValidatorInfo]
    let recommendedValidatorList: [SelectedValidatorInfo]
    let selectedValidatorList: SharedList<SelectedValidatorInfo>
    let maxTargets: Int
    let baseFlow: CustomValidatorListFlow

    private(set) var filteredValidatorList: [SelectedValidatorInfo] = []
    private(set) var viewModel: CustomValidatorListViewModel?
    private(set) var filter: CustomValidatorRelaychainListFilter = .recommendedFilter()

    var filterApplied: Bool {
        let emptyFilter = CustomValidatorRelaychainListFilter.defaultFilter()
        return filter != emptyFilter
    }

    init(
        baseFlow: CustomValidatorListFlow,
        fullValidatorList: [SelectedValidatorInfo],
        recommendedValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: SharedList<SelectedValidatorInfo>,
        maxTargets: Int
    ) {
        self.baseFlow = baseFlow
        self.fullValidatorList = fullValidatorList
        self.recommendedValidatorList = recommendedValidatorList
        self.selectedValidatorList = selectedValidatorList
        self.maxTargets = maxTargets

        filteredValidatorList = composeFilteredValidatorList(filter: filter)
    }

    func validatorInfoFlow(address: String) -> ValidatorInfoFlow? {
        guard let validator = filteredValidatorList.first(where: { $0.address == address }) else {
            return nil
        }

        return .relaychain(validatorInfo: validator, address: nil)
    }

    func validatorSearchFlow() -> ValidatorSearchFlow? {
        .relaychain(
            validatorList: fullValidatorList,
            selectedValidatorList: selectedValidatorList.items,
            delegate: self
        )
    }

    func validatorListFilterFlow() -> ValidatorListFilterFlow? {
        .relaychain(filter: filter)
    }

    func selectedValidatorListFlow() -> SelectedValidatorListFlow? {
        guard !selectedValidatorList.items.isEmpty else {
            return nil
        }

        switch baseFlow {
        case .parachain:
            return nil
        case let .relaychainInitiated(_, _, _, maxTargets, bonding):
            return .relaychainInitiated(
                validatorList: selectedValidatorList.items,
                maxTargets: maxTargets,
                state: bonding
            )
        case let .relaychainExisting(_, _, _, maxTargets, bonding):
            return .relaychainExisting(
                validatorList: selectedValidatorList.items,
                maxTargets: maxTargets,
                state: bonding
            )
        case let .poolExisting(_, _, _, poolId, maxTargets, bonding):
            return .poolExisting(
                validatorList: selectedValidatorList.items,
                poolId: poolId,
                maxTargets: maxTargets,
                state: bonding
            )
        case let .poolInitiated(_, _, _, poolId, maxTargets, bonding):
            return .poolInitiated(
                validatorList: selectedValidatorList.items,
                poolId: poolId,
                maxTargets: maxTargets,
                state: bonding
            )
        }
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        nil
    }

    func performDeselect() {
        selectedValidatorList.set([])

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func changeValidatorSelection(address: String) {
        guard var viewModel = viewModel,
              let changedValidator = filteredValidatorList.first(where: { $0.address == address })
        else {
            return
        }

        guard !changedValidator.blocked else {
            stateListener?.didReceiveError(error: CustomValidatorListFlowError.validatorBlocked)
            return
        }

        if let selectedIndex = selectedValidatorList.firstIndex(of: changedValidator) {
            selectedValidatorList.remove(at: selectedIndex)
            viewModel.selectedValidatorsCount -= 1
        } else {
            selectedValidatorList.append(changedValidator)
            viewModel.selectedValidatorsCount += 1
        }

        if var cellViewModel = viewModel.sections.compactMap({ $0.cells }).reduce([], +).first(where: { $0.address == address }) {
            cellViewModel.isSelected.toggle()
        }
        viewModel.selectedValidatorsCount = selectedValidatorList.count
        self.viewModel = viewModel

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func composeFilteredValidatorList(filter: CustomValidatorRelaychainListFilter) -> [SelectedValidatorInfo] {
        let composer = CustomValidatorRelaychainListComposer(filter: filter)
        return composer.compose(from: fullValidatorList)
    }
}

extension CustomValidatorListRelaychainViewModelState: CustomValidatorListUserInputHandler {
    func proceed() {
        stateListener?.showSelectedList()
    }

    func remove(validator: SelectedValidatorInfo) {
        if let displayedValidator = filteredValidatorList.first(where: { $0.address == validator.address }) {
            changeValidatorSelection(address: displayedValidator.address)
        } else if let selectedIndex = selectedValidatorList.firstIndex(of: validator) {
            selectedValidatorList.remove(at: selectedIndex)

            stateListener?.modelStateDidChanged(viewModelState: self)
        }
    }

    func remove(validatorAddress: AccountAddress) {
        guard let validator = filteredValidatorList.first(where: { $0.address == validatorAddress }) else {
            return
        }

        remove(validator: validator)
    }

    func fillWithRecommended() {
        let recommendedToFill = recommendedValidatorList
            .filter { !selectedValidatorList.contains($0) }
            .prefix(maxTargets - selectedValidatorList.count)

        guard !recommendedToFill.isEmpty else { return }

        selectedValidatorList.append(contentsOf: recommendedToFill)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func updateViewModel(_ viewModel: CustomValidatorListViewModel) {
        self.viewModel = viewModel
    }

    func clearFilter() {
        filter = CustomValidatorRelaychainListFilter.defaultFilter()
        filteredValidatorList = composeFilteredValidatorList(filter: filter)
    }

    func updateFilter(with flow: ValidatorListFilterFlow) {
        guard case let ValidatorListFilterFlow.relaychain(updatedFilter) = flow else {
            return
        }

        filter = updatedFilter

        filteredValidatorList = composeFilteredValidatorList(filter: updatedFilter)
    }
}

extension CustomValidatorListRelaychainViewModelState: ValidatorSearchRelaychainDelegate {
    func validatorSearchDidUpdate(selectedValidatorList: [SelectedValidatorInfo]) {
        self.selectedValidatorList.set(selectedValidatorList)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }
}
