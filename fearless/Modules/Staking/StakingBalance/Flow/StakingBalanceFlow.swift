import UIKit
import SoraFoundation
import SSFModels

enum StakingBalanceFlow {
    case relaychain
    case parachain(
        delegation: ParachainStakingDelegation,
        collator: ParachainStakingCandidateInfo
    )
}

protocol StakingBalanceModelStateListener: AnyObject {
    func modelStateDidChanged(viewModelState: StakingBalanceViewModelState)
    func finishFlow()
    func decideShowSetupRebondFlow()
    func decideShowConfirmRebondFlow(flow: StakingRebondConfirmationFlow)
}

protocol StakingBalanceViewModelState {
    var stateListener: StakingBalanceModelStateListener? { get set }
    var rebondCases: [StakingRebondOption] { get }
    var bondMoreFlow: StakingBondMoreFlow? { get }
    var unbondFlow: StakingUnbondSetupFlow? { get }
    var revokeFlow: StakingRedeemConfirmationFlow? { get }

    func setStateListener(_ stateListener: StakingBalanceModelStateListener?)
    func stakeMoreValidators(using locale: Locale) -> [DataValidating]
    func stakeLessValidators(using locale: Locale) -> [DataValidating]
    func revokeValidators(using locale: Locale) -> [DataValidating]
    func unbondingMoreValidators(using locale: Locale) -> [DataValidating]
    func decideRebondFlow(option: StakingRebondOption)
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
