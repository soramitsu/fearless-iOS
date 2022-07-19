import Foundation

final class ValidatorSearchParachainViewModelState: ValidatorSearchViewModelState {
    var stateListener: ValidatorSearchModelStateListener?
    var searchString: String = ""
    weak var delegate: ValidatorSearchParachainDelegate?
    private(set) var fullValidatorList: [ParachainStakingCandidateInfo]
    private(set) var selectedValidatorList: [ParachainStakingCandidateInfo]
    private(set) var filteredValidatorList: [ParachainStakingCandidateInfo] = []
    private var viewModel: ValidatorSearchViewModel?
    let referenceValidatorList: [ParachainStakingCandidateInfo]

    init(
        fullValidatorList: [ParachainStakingCandidateInfo],
        selectedValidatorList: [ParachainStakingCandidateInfo],
        delegate: ValidatorSearchParachainDelegate?
    ) {
        self.fullValidatorList = fullValidatorList
        self.selectedValidatorList = selectedValidatorList
        referenceValidatorList = selectedValidatorList
        self.delegate = delegate
    }

    func setStateListener(_ stateListener: ValidatorSearchModelStateListener?) {
        self.stateListener = stateListener
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
        }
        .sorted(by: {
            $0.subqueryData?.apr ?? 0.0 > $1.subqueryData?.apr ?? 0.0
        })

        stateListener?.modelStateDidChanged(viewModelState: self)
    }

    func validatorInfoFlow(index: Int) -> ValidatorInfoFlow? {
        let collator = filteredValidatorList[index]

        return .parachain(candidate: collator)
    }

    func changeValidatorSelection(at index: Int) {
        guard var viewModel = viewModel else { return }

        let changedValidator = filteredValidatorList[index]

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

    func applyChanges() {
        delegate?.validatorSearchDidUpdate(selectedValidatorList: selectedValidatorList)
    }
}

extension ValidatorSearchParachainViewModelState: ValidatorSearchParachainStrategyOutput {
    func didReceiveValidatorInfo(_ validatorInfo: ParachainStakingCandidateInfo?) {
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
}
