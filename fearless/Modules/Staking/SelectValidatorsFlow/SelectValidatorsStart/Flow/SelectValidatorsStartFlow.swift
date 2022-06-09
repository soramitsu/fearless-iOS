import Foundation
import RobinHood
import SoraFoundation

enum SelectValidatorsStartFlow {
    case relaychainInitiated(state: InitiatedBonding)
    case relaychainExisting(state: ExistingBonding)
    case parachain(state: InitiatedBonding)

    var phase: SelectValidatorsStartViewController.Phase {
        switch self {
        case .relaychainInitiated:
            return .setup
        case let .relaychainExisting(state):
            return state.selectedTargets == nil ? .setup : .update
        case .parachain:
            return .setup
        }
    }
}

protocol SelectValidatorsStartModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: SelectValidatorsStartViewModelState)
    func didReceiveError(error: Error)
}

protocol SelectValidatorsStartViewModelState: SelectValidatorsStartUserInputHandler {
    var stateListener: SelectValidatorsStartModelStateListener? { get set }

    func setStateListener(_ stateListener: SelectValidatorsStartModelStateListener?)

    var customValidatorListFlow: CustomValidatorListFlow? { get }
    var recommendedValidatorListFlow: RecommendedValidatorListFlow? { get }
}

struct SelectValidatorsStartDependencyContainer {
    let viewModelState: SelectValidatorsStartViewModelState
    let strategy: SelectValidatorsStartStrategy
    let viewModelFactory: SelectValidatorsStartViewModelFactoryProtocol
}

protocol SelectValidatorsStartViewModelFactoryProtocol {
    func buildViewModel(viewModelState: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel?
}

protocol SelectValidatorsStartStrategy {
    func setup()
}

protocol SelectValidatorsStartUserInputHandler {}

extension SelectValidatorsStartUserInputHandler {}
