import Foundation

final class SelectedValidatorListRelaychainViewModelState: SelectedValidatorListViewModelState {
    weak var delegate: SelectedValidatorListDelegate?

    var stateListener: SelectedValidatorListModelStateListener?

    func setStateListener(_ stateListener: SelectedValidatorListModelStateListener?) {
        self.stateListener = stateListener
    }

    let maxTargets: Int
    var selectedValidatorList: [SelectedValidatorInfo]
    let baseFlow: SelectedValidatorListFlow

    init(baseFlow: SelectedValidatorListFlow, maxTargets: Int, selectedValidatorList: [SelectedValidatorInfo], delegate: SelectedValidatorListDelegate?) {
        self.baseFlow = baseFlow
        self.delegate = delegate
        self.maxTargets = maxTargets
        self.selectedValidatorList = selectedValidatorList
    }

    func validatorInfoFlow(validatorIndex: Int) -> ValidatorInfoFlow? {
        .relaychain(validatorInfo: selectedValidatorList[validatorIndex], address: nil)
    }

    func selectValidatorsConfirmFlow() -> SelectValidatorsConfirmFlow? {
        switch baseFlow {
        case let .relaychainInitiated(_, maxTargets, state):
            return .relaychainInitiated(targets: selectedValidatorList, maxTargets: maxTargets, bonding: state)
        case let .relaychainExisting(_, maxTargets, state):
            return .relaychainExisting(targets: selectedValidatorList, maxTargets: maxTargets, bonding: state)
        }
    }
}

extension SelectedValidatorListRelaychainViewModelState: SelectedValidatorListUserInputHandler {
    func removeItem(at index: Int) {
        let validator = selectedValidatorList[index]

        selectedValidatorList.remove(at: index)

        stateListener?.modelStateDidChanged(viewModelState: self)

        delegate?.didRemove(validator)
    }
}
