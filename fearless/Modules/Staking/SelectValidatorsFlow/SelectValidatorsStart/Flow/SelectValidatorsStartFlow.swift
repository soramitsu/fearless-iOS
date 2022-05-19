import Foundation
import RobinHood
import SoraFoundation

enum SelectValidatorsStartFlow {
    case relaychain
    case parachain
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
