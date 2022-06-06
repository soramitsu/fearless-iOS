import UIKit
import SoraFoundation

enum StakingBalanceFlowError: Error {}

enum StakingBalanceFlow {
    case relaychain
    case parachain
}

protocol StakingBalanceModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: StakingBalanceViewModelState)
    func didReceiveError(error: StakingBalanceFlowError)
    func finishFlow()
}

protocol StakingBalanceViewModelState: StakingBalanceUserInputHandler {
    var stateListener: StakingBalanceModelStateListener? { get set }
    func setStateListener(_ stateListener: StakingBalanceModelStateListener?)
}

struct StakingBalanceDependencyContainer {
    let viewModelState: StakingBalanceViewModelState
    let strategy: StakingBalanceStrategy
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
}

protocol StakingBalanceViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingBalanceViewModelState
    ) -> LocalizableResource<StakingBalanceViewModel>?
}

protocol StakingBalanceStrategy {
    func setup()
}

protocol StakingBalanceUserInputHandler {}

extension StakingBalanceUserInputHandler {}
