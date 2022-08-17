import Foundation

final class ValidatorSearchRelaychainViewModelState: ValidatorSearchViewModelState {
    var stateListener: ValidatorSearchModelStateListener?
    private(set) var fullValidatorList: [SelectedValidatorInfo]
    private(set) var selectedValidatorList: [SelectedValidatorInfo]
    private(set) var filteredValidatorList: [SelectedValidatorInfo] = []
    private var viewModel: ValidatorSearchViewModel?
    weak var delegate: ValidatorSearchRelaychainDelegate?
    var searchString: String = ""
    let referenceValidatorList: [SelectedValidatorInfo]

    init(
        fullValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        delegate: ValidatorSearchRelaychainDelegate?
    ) {
        self.fullValidatorList = fullValidatorList
        self.selectedValidatorList = selectedValidatorList
        referenceValidatorList = selectedValidatorList
        self.delegate = delegate
    }

    func setStateListener(_ stateListener: ValidatorSearchModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorInfoFlow(index: Int) -> ValidatorInfoFlow? {
        let validator = filteredValidatorList[index]

        return .relaychain(validatorInfo: validator, address: nil)
    }

    func performFullAddressSearch(by address: AccountAddress, accountId: AccountId) {
        filteredValidatorList = []

        let searchResult = fullValidatorList.first {
            $0.address == address
        }

        guard let validator = searchResult else {
            stateListener?.didNotFoundLocalValidator(accountId: accountId)
            return
        }

        filteredValidatorList.append(validator)

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func performSearch() {
        let nameSearchString = searchString.lowercased()

        filteredValidatorList = fullValidatorList.filter {
            ($0.identity?.displayName.lowercased()
                .contains(nameSearchString) ?? false) ||
                $0.address.hasPrefix(searchString)
        }.sorted(by: {
            $0.stakeReturn > $1.stakeReturn
        })

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func changeValidatorSelection(at index: Int) {
        guard var viewModel = viewModel else { return }

        let changedValidator = filteredValidatorList[index]

        guard !changedValidator.blocked else {
            stateListener?.didReceiveError(error: ValidatorSearchError.validatorBlocked)
            return
        }

        if let selectedIndex = selectedValidatorList.firstIndex(of: changedValidator) {
            selectedValidatorList.remove(at: selectedIndex)
        } else {
            selectedValidatorList.append(changedValidator)
        }

        let differsFromInitial = referenceValidatorList != selectedValidatorList

        viewModel.cellViewModels[index].isSelected.toggle()
        viewModel.differsFromInitial = differsFromInitial
        self.viewModel = viewModel

        stateListener?.viewModelChanged(viewModel)
    }

    func updateViewModel(_ viewModel: ValidatorSearchViewModel?) {
        self.viewModel = viewModel
    }

    func reset() {
        filteredValidatorList = []
        viewModel = nil
    }
}

extension ValidatorSearchRelaychainViewModelState: ValidatorSearchRelaychainStrategyOutput {
    func didReceiveValidatorInfo(_ validatorInfo: SelectedValidatorInfo?) {
        stateListener?.didStopLoading()

        guard let validatorInfo = validatorInfo else {
            filteredValidatorList = []
            stateListener?.modelStateDidChanged(viewModelState: self)
            return
        }

        fullValidatorList.append(validatorInfo)
        filteredValidatorList = [validatorInfo]
        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func didReceiveError(_ error: Error) {
        stateListener?.didReceiveError(error: error)
    }

    func applyChanges() {
        delegate?.validatorSearchDidUpdate(selectedValidatorList: selectedValidatorList)
    }
}
