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

    func stakeMoreValidators(using locale: Locale) -> [DataValidating]
    func stakeLessValidators(using locale: Locale) -> [DataValidating]
    func revokeValidators(using locale: Locale) -> [DataValidating]
}

struct StakingBalanceDependencyContainer {
    let viewModelState: StakingBalanceViewModelState
    let strategy: StakingBalanceStrategy
    let viewModelFactory: StakingBalanceViewModelFactoryProtocol
}

protocol StakingBalanceViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: StakingBalanceViewModelState,
        priceData: PriceData?
    ) -> LocalizableResource<StakingBalanceViewModel>?
}

protocol StakingBalanceStrategy {
    func setup()
}

protocol StakingBalanceUserInputHandler {}

extension StakingBalanceUserInputHandler {}
