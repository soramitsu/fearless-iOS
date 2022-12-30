import Foundation

final class SelectedValidatorListParachainViewModelState: SelectedValidatorListViewModelState {
    weak var delegate: SelectedValidatorListDelegate?
    var stateListener: SelectedValidatorListModelStateListener?
    private(set) var selectedValidatorList: [ParachainStakingCandidateInfo]
    let maxTargets: Int
    let bonding: InitiatedBonding
    let baseFlow: SelectedValidatorListFlow

    init(baseFlow: SelectedValidatorListFlow, maxTargets: Int, selectedValidatorList: [ParachainStakingCandidateInfo], delegate: SelectedValidatorListDelegate?, bonding: InitiatedBonding) {
        self.baseFlow = baseFlow
        self.delegate = delegate
        self.maxTargets = maxTargets
        self.selectedValidatorList = selectedValidatorList
        self.bonding = bonding
    }

    func setStateListener(_ stateListener: SelectedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow? {
        .parachain(candidate: selectedValidatorList[validatorIndex])
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        guard let collator = selectedValidatorList.first else {
            return nil
        }

        return .parachain(target: collator, maxTargets: maxTargets, bonding: bonding)
    }
}

extension SelectedValidatorListParachainViewModelState: SelectedValidatorListUserInputHandler {
    func removeItem(at index: Int) {
        let validator = selectedValidatorList[index]

        selectedValidatorList.remove(at: index)

        stateListener?.modelStateDidChanged(viewModelState: self)

        delegate?.didRemove(validatorAddress: validator.address)
    }
}
